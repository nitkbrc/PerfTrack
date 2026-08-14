class HierarchyRole < ApplicationRecord
  belongs_to :hierarchy
  belongs_to :review_role

  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate :scope_matches_hierarchy
  validate :can_raise_on_behalf_only_when_eligible
  before_destroy :ensure_not_last_role
  before_destroy :block_if_current_on_live_requests

  scope :ordered, -> { order(:position) }

  private

  def scope_matches_hierarchy
    return if hierarchy.blank? || review_role.blank?
    return if hierarchy.scope == review_role.scope

    errors.add(:review_role, "scope must match the hierarchy scope")
  end

  def can_raise_on_behalf_only_when_eligible
    return unless can_raise_on_behalf?
    return if review_role&.raiseable_on_behalf_eligible?

    errors.add(:can_raise_on_behalf, "is only allowed when the review role is raiseable-on-behalf eligible")
  end

  def ensure_not_last_role
    return if destroyed_by_association
    return if hierarchy.blank?
    return if hierarchy.hierarchy_roles.where.not(id: id).exists?

    errors.add(:base, "Cannot remove the last role — each hierarchy needs at least one role")
    throw :abort
  end

  def block_if_current_on_live_requests
    return if destroyed_by_association
    return if hierarchy.blank? || review_role_id.blank?

    owner_ids =
      if hierarchy.scope_division?
        hierarchy.division_ids
      else
        hierarchy.sub_division_ids
      end
    return if owner_ids.empty?

    live = AchievementRequest.in_review.or(AchievementRequest.reverted)
                             .where(current_review_role_id: review_role_id)
    if hierarchy.scope_division?
      live = live.joins(category: { sub_division: :division }).where(divisions: { id: owner_ids })
    else
      live = live.joins(category: :sub_division).where(sub_divisions: { id: owner_ids })
    end

    return unless live.exists?

    errors.add(:base, "Cannot remove a role that in-flight requests are currently sitting on")
    throw :abort
  end
end
