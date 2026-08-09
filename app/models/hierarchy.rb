class Hierarchy < ApplicationRecord
  has_many :hierarchy_roles, -> { order(:position) }, dependent: :destroy, inverse_of: :hierarchy
  has_many :review_roles, through: :hierarchy_roles
  has_many :divisions, dependent: :restrict_with_exception
  has_many :sub_divisions, dependent: :restrict_with_exception

  enum :scope, { division: "division", sub_division: "sub_division" }, prefix: true

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :scope, presence: true
  validate :exactly_one_default_per_scope, if: :is_default?

  before_destroy :prevent_destroy_when_in_use, prepend: true
  before_destroy :prevent_default_destroy, prepend: true

  scope :for_scope, ->(scope) { where(scope: scope) }
  scope :defaults, -> { where(is_default: true) }

  def self.ensure_defaults!
    ReviewRole.ensure_system_roles!

    division_default = find_or_create_by!(name: "Default Division Hierarchy") do |h|
      h.scope = "division"
      h.is_default = !exists?(scope: "division", is_default: true)
    end
    if where(scope: "division", is_default: true).none?
      division_default.update!(is_default: true, scope: "division")
    end
    division_default.hierarchy_roles.find_or_create_by!(review_role: ReviewRole.dean) do |hr|
      hr.position = 1
      hr.can_raise_on_behalf = false
    end

    sub_default = find_or_create_by!(name: "Default Sub-division Hierarchy") do |h|
      h.scope = "sub_division"
      h.is_default = !exists?(scope: "sub_division", is_default: true)
    end
    if where(scope: "sub_division", is_default: true).none?
      sub_default.update!(is_default: true, scope: "sub_division")
    end
    sub_default.hierarchy_roles.find_or_create_by!(review_role: ReviewRole.supervisor) do |hr|
      hr.position = 1
      hr.can_raise_on_behalf = true
    end

    [ division_default, sub_default ]
  end

  def self.default_for(scope)
    ensure_defaults!
    find_by!(scope: scope, is_default: true)
  end

  # Promote this template to the sole default for its scope. Existing owners
  # stay on their current hierarchy; only new units pick up the new default.
  def make_default!
    transaction do
      Hierarchy.where(scope: scope, is_default: true).where.not(id: id).update_all(
        is_default: false,
        updated_at: Time.current
      )
      update!(is_default: true)
    end
    self
  end

  def owners
    scope_division? ? divisions : sub_divisions
  end

  def usage_count
    owners.count
  end

  def in_use?
    usage_count.positive?
  end

  # Insert a role after Supervisor (sub) or before Dean (div).
  def insert_role!(review_role, can_raise_on_behalf: false)
    raise ArgumentError, "scope mismatch" unless review_role.scope == scope

    transaction do
      roles = hierarchy_roles.includes(:review_role).to_a
      raise ArgumentError, "role already in hierarchy" if roles.any? { |r| r.review_role_id == review_role.id }

      new_hr = hierarchy_roles.build(
        review_role: review_role,
        can_raise_on_behalf: can_raise_on_behalf && review_role.raiseable_on_behalf_eligible?,
        position: (roles.map(&:position).max || 0) + 1
      )
      new_hr.save!
      normalize_positions!
      new_hr
    end
  end

  def normalize_positions!
    roles = hierarchy_roles.includes(:review_role).to_a
    return if roles.empty?

    ordered =
      if scope_sub_division?
        supervisor = roles.find { |r| r.review_role.supervisor? }
        others = (roles - [ supervisor ].compact).sort_by(&:position)
        [ supervisor ].compact + others
      else
        dean = roles.find { |r| r.review_role.dean? }
        others = (roles - [ dean ].compact).sort_by(&:position)
        others + [ dean ].compact
      end

    # Park in a free positive range first so unique (hierarchy_id, position)
    # never clashes and position validations never see negatives.
    transaction do
      ordered.each_with_index { |hr, i| hr.update_columns(position: 10_000 + i, updated_at: Time.current) }
      ordered.each_with_index { |hr, i| hr.update_columns(position: i + 1, updated_at: Time.current) }
    end
  end

  # Signature used to group identical owner step lists into one template.
  def self.signature_for_steps(steps)
    steps.sort_by(&:position).map { |s| [ s.review_role_id, s.can_raise_on_behalf? ] }
  end

  private

  def exactly_one_default_per_scope
    other = Hierarchy.where(scope: scope, is_default: true)
    other = other.where.not(id: id) if persisted?
    return unless other.exists?

    errors.add(:is_default, "already set for another hierarchy in this scope")
  end

  def prevent_default_destroy
    return unless is_default?

    errors.add(:base, "Default hierarchies cannot be deleted")
    throw :abort
  end

  def prevent_destroy_when_in_use
    return unless in_use?

    errors.add(:base, "Cannot delete a hierarchy that is still in use")
    throw :abort
  end
end
