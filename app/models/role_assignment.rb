class RoleAssignment < ApplicationRecord
  belongs_to :user
  belongs_to :review_role
  belongs_to :division, optional: true
  belongs_to :sub_division, optional: true

  validates :user_id, uniqueness: {
    scope: [ :review_role_id, :division_id, :sub_division_id ],
    message: "is already assigned this role here"
  }
  validate :exactly_one_scope_owner
  validate :scope_matches_review_role
  validate :exclusivity_rules
  validate :user_is_faculty
  validate :slot_not_taken_by_another_user
  validate :role_on_owner_hierarchy

  def self.holder_for(review_role:, division: nil, sub_division: nil)
    scope = where(review_role_id: review_role.is_a?(ReviewRole) ? review_role.id : review_role)
    if division.present?
      scope.find_by(division_id: division.is_a?(Division) ? division.id : division)&.user
    elsif sub_division.present?
      scope.find_by(sub_division_id: sub_division.is_a?(SubDivision) ? sub_division.id : sub_division)&.user
    end
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

  def user_is_faculty
    return if user.blank? || user.faculty?

    errors.add(:user, "must be a faculty member")
  end

  def slot_not_taken_by_another_user
    return if review_role.blank?

    scope = RoleAssignment.where(review_role_id: review_role_id)
    scope = if division_id.present?
      scope.where(division_id: division_id)
    elsif sub_division_id.present?
      scope.where(sub_division_id: sub_division_id)
    else
      return
    end
    scope = scope.where.not(id: id) if persisted?
    scope = scope.where.not(user_id: user_id) if user_id.present?
    return unless scope.exists?

    errors.add(:base, "#{review_role.name} is already assigned here — edit the existing assignment to change the person")
  end

  def role_on_owner_hierarchy
    return if review_role.blank?

    hierarchy = if division_id.present?
      Division.find_by(id: division_id)&.hierarchy
    elsif sub_division_id.present?
      SubDivision.find_by(id: sub_division_id)&.hierarchy
    end
    return if hierarchy.blank?
    return if hierarchy.hierarchy_roles.exists?(review_role_id: review_role_id)

    errors.add(:review_role, "is not part of this #{division_id.present? ? 'division' : 'sub-division'}'s hierarchy")
  end

  # Division-scoped: no other role anywhere.
  # Sub-division-scoped: same role across sub-divisions OK; no different role type.
  def exclusivity_rules
    return if user.blank? || review_role.blank?

    others = RoleAssignment.where(user_id: user_id)
    others = others.where.not(id: id) if persisted?

    if review_role.scope_division?
      if others.exists?
        errors.add(:user, "already holds another review role and cannot take a division-scoped role")
      end
    else
      conflicting = others.joins(:review_role).where.not(review_roles: { id: review_role_id })
      if conflicting.exists?
        errors.add(:user, "already holds a different review role")
      end
      if others.joins(:review_role).merge(ReviewRole.scope_division).exists?
        errors.add(:user, "already holds a division-scoped role")
      end
    end
  end
end
