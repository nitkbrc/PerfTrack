class SubDivisionRaiseableOverride < ApplicationRecord
  belongs_to :sub_division
  belongs_to :review_role

  validates :review_role_id, uniqueness: { scope: :sub_division_id }
  validate :role_must_be_raiseable_eligible
  validate :role_must_be_on_sub_hierarchy

  private

  def role_must_be_raiseable_eligible
    return if review_role.blank?
    return if review_role.raiseable_on_behalf_eligible?

    errors.add(:review_role, "must be raiseable-on-behalf eligible")
  end

  def role_must_be_on_sub_hierarchy
    return if sub_division.blank? || review_role.blank?
    hierarchy = sub_division.hierarchy
    return if hierarchy.blank?
    return if hierarchy.hierarchy_roles.exists?(review_role_id: review_role_id)

    errors.add(:review_role, "must be part of the sub-division's hierarchy")
  end
end
