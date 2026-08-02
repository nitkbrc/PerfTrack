class HierarchyStep < ApplicationRecord
  belongs_to :review_role
  belongs_to :division, optional: true
  belongs_to :sub_division, optional: true
  has_many :current_requests, class_name: "AchievementRequest", foreign_key: :current_step_id,
                              dependent: :nullify, inverse_of: :current_step

  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate :exactly_one_scope_owner
  validate :scope_matches_review_role
  validate :can_raise_on_behalf_only_when_eligible

  scope :ordered, -> { order(:position) }
  scope :for_division, ->(division) { where(division_id: division.is_a?(Division) ? division.id : division) }
  scope :for_sub_division, ->(sub_division) {
    where(sub_division_id: sub_division.is_a?(SubDivision) ? sub_division.id : sub_division)
  }

  def scope_owner
    division || sub_division
  end

  def assigned_user
    RoleAssignment.holder_for(review_role: review_role, division: division, sub_division: sub_division)
  end

  private

  def exactly_one_scope_owner
    if division_id.present? == sub_division_id.present?
      errors.add(:base, "exactly one of division or sub_division must be set")
    end
  end

  def scope_matches_review_role
    return if review_role.blank?

    if review_role.scope_division? && division_id.blank?
      errors.add(:division, "must be set for a division-scoped role")
    elsif review_role.scope_sub_division? && sub_division_id.blank?
      errors.add(:sub_division, "must be set for a sub-division-scoped role")
    end
  end

  def can_raise_on_behalf_only_when_eligible
    return unless can_raise_on_behalf?
    return if review_role&.raiseable_on_behalf_eligible?

    errors.add(:can_raise_on_behalf, "is only allowed when the review role is raiseable-on-behalf eligible")
  end
end
