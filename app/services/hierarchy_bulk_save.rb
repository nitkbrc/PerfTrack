# Applies a staged hierarchy-templates changeset in one transaction.
# Remaps in-flight requests onto the new live chain before obsolete roles
# are removed so nothing is stranded mid-review.
class HierarchyBulkSave
  class Error < StandardError
    attr_reader :details

    def initialize(message, details = [])
      super(message)
      @details = Array(details)
    end
  end

  def initialize(payload, actor: nil)
    @payload = payload.deep_symbolize_keys
    @actor = actor
    @pending_role_destroys = []
  end

  def call!
    ActiveRecord::Base.transaction do
      snapshots = snapshot_in_flight_requests!

      Array(@payload[:hierarchies]).each { |h| apply_hierarchy!(h) }
      Array(@payload[:reattachments]).each { |r| apply_reattach!(r) }

      remap_in_flight_requests!(snapshots)
      flush_pending_role_destroys!

      Array(@payload[:deleted_hierarchy_ids]).each { |id| destroy_hierarchy!(id) }
    end
    true
  end

  private

  def snapshot_in_flight_requests!
    request_ids = Set.new

    Array(@payload[:hierarchies]).each do |data|
      next if data[:id].blank?

      hierarchy = Hierarchy.find_by(id: data[:id])
      next unless hierarchy

      in_review_requests_for_hierarchy(hierarchy).each { |req| request_ids << req.id }
    end

    Array(@payload[:reattachments]).each do |data|
      owner = find_owner(data[:owner_type], data[:owner_id])
      next unless owner

      in_review_requests_for_owner(owner).each { |req| request_ids << req.id }
    end

    AchievementRequest.where(id: request_ids.to_a).in_review.includes(
      :current_review_role,
      :req_histories,
      category: { sub_division: :division },
      student: :user,
      request_versions: []
    ).map do |request|
      {
        request_id: request.id,
        old_chain_role_ids: InFlightRequestRemapper.staffed_chain_role_ids(request),
        previous_role_id: request.current_review_role_id
      }
    end
  end

  def remap_in_flight_requests!(snapshots)
    return if snapshots.empty?
    raise Error, "Cannot reassign in-flight requests without a signed-in admin actor." if @actor.blank?

    remapper = InFlightRequestRemapper.new(actor: @actor)

    snapshots.each do |snap|
      request = AchievementRequest.find_by(id: snap[:request_id])
      next unless request&.in_review?

      remapper.remap!(
        request: request,
        old_chain_role_ids: snap[:old_chain_role_ids],
        new_chain_role_ids: intended_staffed_chain_role_ids(request)
      )
    end
  end

  def in_review_requests_for_hierarchy(hierarchy)
    if hierarchy.scope_division?
      AchievementRequest.in_review
                        .joins(category: { sub_division: :division })
                        .where(divisions: { id: hierarchy.division_ids })
    else
      AchievementRequest.in_review
                        .joins(category: :sub_division)
                        .where(sub_divisions: { id: hierarchy.sub_division_ids })
    end
  end

  def in_review_requests_for_owner(owner)
    if owner.is_a?(Division)
      AchievementRequest.in_review
                        .joins(category: { sub_division: :division })
                        .where(divisions: { id: owner.id })
    else
      AchievementRequest.in_review
                        .joins(category: :sub_division)
                        .where(sub_divisions: { id: owner.id })
    end
  end

  def find_owner(owner_type, owner_id)
    case owner_type.to_s
    when "Division" then Division.find_by(id: owner_id)
    when "SubDivision" then SubDivision.find_by(id: owner_id)
    end
  end

  def apply_hierarchy!(data)
    hierarchy = find_hierarchy!(data)

    if data[:name].present?
      hierarchy.update!(name: data[:name].to_s.strip)
    end

    desired = normalize_desired_roles!(data, hierarchy)
    sync_roles!(hierarchy, desired)
    normalize_positions_excluding_pending!(hierarchy)
  end

  def normalize_positions_excluding_pending!(hierarchy)
    pending = @pending_role_destroys.to_set
    roles = hierarchy.hierarchy_roles.includes(:review_role).to_a.reject { |hr| pending.include?(hr.id) }
    return if roles.empty?

    ordered =
      if hierarchy.scope_sub_division?
        supervisor = roles.find { |r| r.review_role.supervisor? }
        others = (roles - [ supervisor ].compact).sort_by(&:position)
        [ supervisor ].compact + others
      else
        dean = roles.find { |r| r.review_role.dean? }
        others = (roles - [ dean ].compact).sort_by(&:position)
        others + [ dean ].compact
      end

    ordered.each_with_index { |hr, i| hr.update_columns(position: 30_000 + i, updated_at: Time.current) }
    ordered.each_with_index { |hr, i| hr.update_columns(position: i + 1, updated_at: Time.current) }
    hierarchy.hierarchy_roles.reload
  end

  def intended_staffed_chain_role_ids(request)
    pending = @pending_role_destroys.to_set
    sub_division = request.category.sub_division
    division = sub_division.division
    ids = []

    append_staffed_roles = lambda do |owner|
      next if owner.blank? || owner.hierarchy.blank?

      owner.hierarchy.hierarchy_roles.includes(:review_role, :hierarchy).ordered.each do |hierarchy_role|
        next if pending.include?(hierarchy_role.id)

        user = RoleAssignment.holder_for(
          review_role: hierarchy_role.review_role,
          division: owner.is_a?(Division) ? owner : nil,
          sub_division: owner.is_a?(SubDivision) ? owner : nil
        )
        ids << hierarchy_role.review_role_id if user
      end
    end

    append_staffed_roles.call(sub_division)
    append_staffed_roles.call(division)
    ids
  end

  def find_hierarchy!(data)
    if data[:id].present?
      Hierarchy.find(data[:id])
    else
      scope = data[:scope].to_s
      raise Error, "Invalid hierarchy scope" unless %w[division sub_division].include?(scope)

      Hierarchy.create!(
        name: unique_name(data[:name].presence || "New #{scope == 'division' ? 'Division' : 'Sub-division'} Hierarchy"),
        scope: scope,
        is_default: false
      )
    end
  rescue ActiveRecord::RecordNotFound
    raise Error, "Hierarchy ##{data[:id]} was not found — refresh the page and try again."
  end

  def normalize_desired_roles!(data, hierarchy)
    desired = Array(data[:roles]).filter_map do |role_data|
      role_id = role_data[:review_role_id].to_i
      next if role_id <= 0

      {
        review_role_id: role_id,
        can_raise_on_behalf: ActiveModel::Type::Boolean.new.cast(role_data[:can_raise_on_behalf])
      }
    end

    raise Error, "Each hierarchy needs at least one role" if desired.empty?

    ids = desired.map { |d| d[:review_role_id] }
    if ids.uniq.size != ids.size
      raise Error, "Duplicate roles are not allowed in the same hierarchy"
    end

    desired.each do |attrs|
      role = ReviewRole.find_by(id: attrs[:review_role_id])
      raise Error, "Review role ##{attrs[:review_role_id]} was not found" unless role
      unless role.scope == hierarchy.scope
        raise Error, "Role \"#{role.name}\" cannot be used on a #{hierarchy.scope.tr('_', '-')} hierarchy"
      end
      attrs[:review_role] = role
      attrs[:can_raise_on_behalf] = attrs[:can_raise_on_behalf] && role.raiseable_on_behalf_eligible?
    end

    desired
  end

  def sync_roles!(hierarchy, desired)
    desired_ids = desired.map { |d| d[:review_role_id] }

    # 1. Park existing positions in a free positive range so reordering never
    # collides with the unique (hierarchy_id, position) index, and never
    # trips "position must be greater than 0".
    hierarchy.hierarchy_roles.order(:id).each_with_index do |hr, index|
      hr.update_columns(position: 10_000 + index, updated_at: Time.current)
    end

    # 2. Upsert desired roles FIRST so we never destroy the last remaining role
    # before its replacement exists (ensure_not_last_role callback).
    desired.each_with_index do |attrs, index|
      hr = HierarchyRole.find_or_initialize_by(
        hierarchy_id: hierarchy.id,
        review_role_id: attrs[:review_role_id]
      )
      hr.can_raise_on_behalf = attrs[:can_raise_on_behalf]
      hr.position = 20_000 + index
      begin
        hr.save!
      rescue ActiveRecord::RecordInvalid => e
        raise Error, e.record.errors.full_messages.to_sentence.presence || e.message
      end
    end

    # 3. Defer obsolete role removal until in-flight requests have been remapped
    # onto the new chain (otherwise block_if_current_on_live_requests aborts).
    HierarchyRole.where(hierarchy_id: hierarchy.id).where.not(review_role_id: desired_ids).find_each do |hr|
      @pending_role_destroys << hr.id
    end

    # 4. Assign final review-order positions 1..N on desired roles only.
    desired.each_with_index do |attrs, index|
      hr = HierarchyRole.find_by!(hierarchy_id: hierarchy.id, review_role_id: attrs[:review_role_id])
      hr.update_columns(position: index + 1, updated_at: Time.current)
    end

    hierarchy.hierarchy_roles.reload
  end

  def flush_pending_role_destroys!
    HierarchyRole.where(id: @pending_role_destroys.uniq).find_each do |hr|
      destroy_hierarchy_role!(hr)
    end
    @pending_role_destroys.clear
  end

  def destroy_hierarchy_role!(hr)
    hierarchy = hr.hierarchy
    review_role_id = hr.review_role_id

    unless hr.destroy
      message = hr.errors.full_messages.to_sentence.presence ||
                "Could not remove \"#{hr.review_role&.name || 'role'}\" from #{hierarchy.name}"
      raise Error, message
    end

    # Drop assignments for this role on every owner still on the template so
    # exclusivity rules don't keep blocking faculty for an invisible slot.
    purge_assignments_for_role!(hierarchy, review_role_id)
  end

  def purge_assignments_for_role!(hierarchy, review_role_id)
    scope =
      if hierarchy.scope_division?
        RoleAssignment.where(review_role_id: review_role_id, division_id: hierarchy.division_ids)
      else
        RoleAssignment.where(review_role_id: review_role_id, sub_division_id: hierarchy.sub_division_ids)
      end

    scope.find_each do |assignment|
      assignment.destroy!
    rescue ActiveRecord::RecordNotDestroyed => e
      raise Error, e.record.errors.full_messages.to_sentence.presence ||
                   "Could not remove an obsolete assignment for #{assignment.user&.name || 'a faculty member'}"
    end
  end

  def apply_reattach!(data)
    owner_type = data[:owner_type].to_s
    owner =
      case owner_type
      when "Division" then Division.find(data[:owner_id])
      when "SubDivision" then SubDivision.find(data[:owner_id])
      else
        raise Error, "Unknown owner type: #{owner_type}"
      end

    new_hierarchy = Hierarchy.find(data[:hierarchy_id])
    expected_scope = owner.is_a?(Division) ? "division" : "sub_division"
    unless new_hierarchy.scope == expected_scope
      raise Error, "Cannot attach #{owner_type} to a #{new_hierarchy.scope.tr('_', '-')} hierarchy"
    end

    return if owner.hierarchy_id == new_hierarchy.id

    owner.update!(hierarchy: new_hierarchy)

    keep_role_ids = new_hierarchy.hierarchy_roles.pluck(:review_role_id)
    # Exclude roles queued for destruction on the destination template.
    keep_role_ids -= HierarchyRole.where(id: @pending_role_destroys).pluck(:review_role_id)

    owner.role_assignments.where.not(review_role_id: keep_role_ids).find_each do |assignment|
      assignment.destroy!
    rescue ActiveRecord::RecordNotDestroyed => e
      raise Error, e.record.errors.full_messages.to_sentence.presence ||
                   "Could not drop an obsolete role assignment for #{owner.name}"
    end
  rescue ActiveRecord::RecordNotFound
    raise Error, "Could not reattach an owner — refresh the page and try again."
  rescue ActiveRecord::RecordInvalid => e
    raise Error, e.record.errors.full_messages.to_sentence.presence || e.message
  end

  def destroy_hierarchy!(id)
    hierarchy = Hierarchy.find_by(id: id)
    return unless hierarchy

    unless hierarchy.destroy
      raise Error, hierarchy.errors.full_messages.to_sentence.presence || "Could not delete hierarchy"
    end
  end

  def unique_name(base)
    name = base.to_s.strip
    name = "New Hierarchy" if name.blank?
    candidate = name
    n = 2
    while Hierarchy.exists?([ "LOWER(name) = ?", candidate.downcase ])
      candidate = "#{name} (#{n})"
      n += 1
    end
    candidate
  end
end
