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

  before_destroy :ensure_not_last_step_on_owner

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

  def supervisor_anchor?
    review_role&.supervisor?
  end

  def dean_anchor?
    review_role&.dean?
  end

  # Supervisor (if present) first; Dean (if present) last; other roles keep relative order.
  def self.normalize_positions_for!(owner)
    steps = owner.hierarchy_steps.includes(:review_role).to_a
    return if steps.empty?

    ordered =
      if owner.is_a?(SubDivision)
        supervisor = steps.find(&:supervisor_anchor?)
        others = (steps - [ supervisor ].compact).sort_by(&:position)
        [ supervisor ].compact + others
      else
        dean = steps.find(&:dean_anchor?)
        others = (steps - [ dean ].compact).sort_by(&:position)
        others + [ dean ].compact
      end

    transaction do
      ordered.each_with_index do |step, index|
        step.update_columns(position: -(index + 1))
      end
      ordered.each_with_index do |step, index|
        step.update_columns(position: index + 1)
      end
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

  def can_raise_on_behalf_only_when_eligible
    return unless can_raise_on_behalf?
    return if review_role&.raiseable_on_behalf_eligible?

    errors.add(:can_raise_on_behalf, "is only allowed when the review role is raiseable-on-behalf eligible")
  end

  def ensure_not_last_step_on_owner
    owner = scope_owner
    return if owner.blank?
    return if owner.hierarchy_steps.where.not(id: id).exists?

    errors.add(:base, "Cannot remove the last review step — each #{owner_label} needs at least one role")
    throw :abort
  end

  def owner_label
    division_id.present? ? "division" : "sub-division"
  end
end
