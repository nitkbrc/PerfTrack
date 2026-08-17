class Division < ApplicationRecord
  include Archivable

  belongs_to :hierarchy

  has_many :sub_divisions
  has_many :role_assignments, dependent: :destroy
  has_many :reason_templates, dependent: :destroy
  has_many :reason_template_suppressions, dependent: :destroy

  enum :div_type, { positive: "positive", negative: "negative" }

  before_validation :assign_default_hierarchy, on: :create

  validate :hierarchy_scope_must_be_division

  before_destroy :purge_descendants_for_permanent_delete!, prepend: true
  before_destroy :prevent_destroy_with_approved_history, prepend: true
  before_destroy :prevent_destroy_unless_archived, prepend: true

  def dean
    RoleAssignment.holder_for(review_role: ReviewRole.dean, division: self)
  end

  def dean_assignment
    role_assignments.find_by(review_role: ReviewRole.dean)
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

  def approved_requests
    AchievementRequest.approved
                      .joins(category: :sub_division)
                      .where(sub_divisions: { division_id: id })
  end

  def approved_request_history?
    approved_requests.exists?
  end

  def archive!(stamp = Time.current, actor: nil)
    transaction do
      update!(archived_at: stamp)
      sub_divisions.active.find_each { |sub_division| sub_division.archive!(stamp, actor: actor) }
    end
  end

  def restore!
    transaction do
      stamp = archived_at
      update!(archived_at: nil)
      sub_divisions.where(archived_at: stamp).find_each(&:restore!)
    end
  end

  private

  def assign_default_hierarchy
    return if hierarchy_id.present?

    self.hierarchy = Hierarchy.default_for("division")
  end

  def hierarchy_scope_must_be_division
    return if hierarchy.blank?
    return if hierarchy.scope_division?

    errors.add(:hierarchy, "must be a division-scoped hierarchy")
  end

  def prevent_destroy_unless_archived
    return if archived?

    errors.add(:base, "Only archived divisions can be permanently deleted. Archive it first.")
    throw :abort
  end

  def prevent_destroy_with_approved_history
    return unless approved_request_history?

    errors.add(:base, "Cannot permanently delete — this division has approved request history. Leave it archived.")
    throw :abort
  end

  # Non-approved requests, categories, and sub-divisions are removed so the
  # division hard-delete can succeed under FK constraints.
  def purge_descendants_for_permanent_delete!
    sub_divisions.find_each do |sub_division|
      sub_division.categories.find_each do |category|
        category.achievement_requests.find_each(&:destroy!)
        category.destroy!
      end
      sub_division.destroy!
    end
  end
end
