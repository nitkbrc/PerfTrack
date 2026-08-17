class SubDivision < ApplicationRecord
  include Archivable

  belongs_to :division
  belongs_to :hierarchy

  has_many :categories
  has_many :active_categories, -> { active }, class_name: "Category"
  has_many :role_assignments, dependent: :destroy
  has_many :raiseable_overrides, class_name: "SubDivisionRaiseableOverride", dependent: :destroy

  before_validation :assign_default_hierarchy, on: :create

  validate :hierarchy_scope_must_be_sub_division

  def supervisor
    RoleAssignment.holder_for(review_role: ReviewRole.supervisor, sub_division: self)
  end

  def supervisor_assignment
    role_assignments.find_by(review_role: ReviewRole.supervisor)
  end

  def hierarchy_staffed?
    return false if hierarchy.blank?

    assigned_review_role_ids = role_assignments.map(&:review_role_id)
    hierarchy.hierarchy_roles.all? { |hr| assigned_review_role_ids.include?(hr.review_role_id) }
  end

  def unstaffed_review_roles
    return [] if hierarchy.blank?

    assigned_review_role_ids = role_assignments.map(&:review_role_id)
    hierarchy.hierarchy_roles.filter_map do |hr|
      hr.review_role unless assigned_review_role_ids.include?(hr.review_role_id)
    end
  end

  def effective_can_raise_on_behalf?(review_role)
    role = review_role.is_a?(ReviewRole) ? review_role : ReviewRole.find(review_role)
    return false unless role.raiseable_on_behalf_eligible?

    override = raiseable_overrides.find_by(review_role_id: role.id)
    return override.can_raise_on_behalf? if override

    hierarchy_role = hierarchy&.hierarchy_roles&.find_by(review_role_id: role.id)
    hierarchy_role&.can_raise_on_behalf? || false
  end

  # Same shared-timestamp cascade as Division#archive! (see comment there).
  def archive!(stamp = Time.current, actor: nil)
    transaction do
      update!(archived_at: stamp)
      categories.active.find_each { |category| category.archive!(stamp, actor: actor) }
    end
  end

  def restore!
    transaction do
      stamp = archived_at
      update!(archived_at: nil)
      categories.where(archived_at: stamp).find_each(&:restore!)
    end
  end

  private

  def assign_default_hierarchy
    return if hierarchy_id.present?

    self.hierarchy = Hierarchy.default_for("sub_division")
  end

  def hierarchy_scope_must_be_sub_division
    return if hierarchy.blank?
    return if hierarchy.scope_sub_division?

    errors.add(:hierarchy, "must be a sub-division-scoped hierarchy")
  end
end
