module Admin
  class HierarchiesController < BaseController
    def index
      authorize Hierarchy
      Hierarchy.ensure_defaults!
      load_index
    end

    def create
      authorize Hierarchy
      scope = params.require(:scope)
      raise ActionController::ParameterMissing, :scope unless %w[division sub_division].include?(scope)

      ReviewRole.ensure_system_roles!
      base_name = params[:name].presence || "New #{scope == 'division' ? 'Division' : 'Sub-division'} Hierarchy"
      hierarchy = Hierarchy.new(
        name: unique_hierarchy_name(base_name),
        scope: scope,
        is_default: false
      )

      ActiveRecord::Base.transaction do
        hierarchy.save!
        default_role = scope == "division" ? ReviewRole.dean : ReviewRole.supervisor
        hierarchy.hierarchy_roles.create!(
          review_role: default_role,
          position: 1,
          can_raise_on_behalf: default_role.raiseable_on_behalf_eligible?
        )
      end

      redirect_to admin_hierarchies_path, notice: "Hierarchy created."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_hierarchies_path, alert: e.record.errors.full_messages.to_sentence
    end

    def destroy
      hierarchy = authorize Hierarchy.find(params[:id])
      hierarchy.destroy!
      redirect_to admin_hierarchies_path, notice: "Hierarchy deleted."
    rescue ActiveRecord::RecordNotDestroyed => e
      message = hierarchy.errors.full_messages.to_sentence.presence ||
                e.record.errors.full_messages.to_sentence.presence ||
                "Could not delete."
      redirect_to admin_hierarchies_path, alert: message
    rescue ActiveRecord::DeleteRestrictionError
      redirect_to admin_hierarchies_path, alert: "Cannot delete a hierarchy that is still in use."
    end

    def make_default
      hierarchy = authorize Hierarchy.find(params[:id]), :update?
      hierarchy.make_default!
      redirect_to admin_hierarchies_path, notice: "“#{hierarchy.name}” is now the default #{hierarchy.scope.humanize.downcase} hierarchy."
    rescue ActiveRecord::RecordInvalid
      redirect_to admin_hierarchies_path, alert: hierarchy.errors.full_messages.to_sentence.presence || "Could not set default."
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_hierarchies_path, alert: "Hierarchy not found."
    end

    def bulk_save
      authorize Hierarchy, :update?
      raw = params.require(:payload)
      payload = raw.is_a?(String) ? JSON.parse(raw) : raw.to_unsafe_h
      HierarchyBulkSave.new(payload, actor: current_user).call!
      redirect_to admin_hierarchies_path, notice: "Hierarchies saved."
    rescue HierarchyBulkSave::Error => e
      redirect_to admin_hierarchies_path, alert: e.message
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_hierarchies_path, alert: e.record.errors.full_messages.to_sentence
    rescue ActiveRecord::RecordNotUnique
      redirect_to admin_hierarchies_path, alert: "Could not save because of a role-order conflict. Refresh and try again."
    rescue ActiveRecord::RecordNotDestroyed => e
      redirect_to admin_hierarchies_path, alert: e.record.errors.full_messages.to_sentence.presence || e.message
    rescue ActionController::ParameterMissing
      redirect_to admin_hierarchies_path, alert: "Nothing to save. Refresh the page and try again."
    rescue JSON::ParserError
      redirect_to admin_hierarchies_path, alert: "Invalid save payload. Refresh the page and try again."
    end

    def create_role
      authorize ReviewRole, :create?
      scope = params.require(:scope)
      unless %w[division sub_division].include?(scope)
        redirect_to admin_hierarchies_path, alert: "Invalid role scope."
        return
      end

      name = params[:name].to_s.strip
      if name.blank?
        redirect_to admin_hierarchies_path, alert: "Role name can't be blank."
        return
      end

      role = ReviewRole.new(
        name: name,
        scope: scope,
        system_role: false,
        raiseable_on_behalf_eligible: scope == "sub_division" && ActiveModel::Type::Boolean.new.cast(params[:raiseable_on_behalf_eligible])
      )
      role.save!
      redirect_to admin_hierarchies_path, notice: "Role \"#{role.name}\" created. Add it to a template, then save."
    rescue ActiveRecord::RecordInvalid
      redirect_to admin_hierarchies_path, alert: role.errors.full_messages.to_sentence
    end

    private

    def load_index
      # Owners are preloaded so cards can filter/sort in memory instead of
      # issuing a query (plus a staffing query per role) for every card.
      @division_hierarchies = Hierarchy.scope_division
                                       .includes(hierarchy_roles: :review_role, divisions: :role_assignments)
                                       .sort_by { |h| [ h.is_default? ? 1 : 0, h.name ] }
      @sub_division_hierarchies = Hierarchy.scope_sub_division
                                           .includes(hierarchy_roles: :review_role, sub_divisions: [ :role_assignments, :division ])
                                           .sort_by { |h| [ h.is_default? ? 1 : 0, h.name ] }
      @division_roles = ReviewRole.scope_division.order(:name)
      @sub_division_roles = ReviewRole.scope_sub_division.order(:name)
      @unassigned_divisions = Division.active.where(hierarchy_id: nil).includes(:role_assignments).order(:name)
      @unassigned_sub_divisions = SubDivision.active.where(hierarchy_id: nil).includes(:role_assignments, :division).order(:name)
      @stats = index_stats
    end

    def index_stats
      attached = (@division_hierarchies + @sub_division_hierarchies).flat_map { |h| h.owners.reject(&:archived?) }

      {
        templates: @division_hierarchies.size + @sub_division_hierarchies.size,
        attached: attached.size,
        unstaffed: attached.count { |owner| !owner.hierarchy_staffed? },
        unattached: @unassigned_divisions.size + @unassigned_sub_divisions.size
      }
    end

    def unique_hierarchy_name(base)
      name = base.to_s.strip
      name = "New Hierarchy" if name.blank?
      candidate = name
      n = 2
      while Hierarchy.exists?(["LOWER(name) = ?", candidate.downcase])
        candidate = "#{name} (#{n})"
        n += 1
      end
      candidate
    end
  end
end
