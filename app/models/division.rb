class Division < ApplicationRecord
  include Archivable

  has_many :sub_divisions
  has_many :hierarchy_steps, dependent: :destroy
  has_many :role_assignments, dependent: :destroy

  enum :div_type, { positive: "positive", negative: "negative" }

  after_create :ensure_default_dean_step!

  def dean
    RoleAssignment.holder_for(review_role: ReviewRole.dean, division: self)
  end

  def dean_assignment
    role_assignments.find_by(review_role: ReviewRole.dean)
  end

  # The whole cascade shares one timestamp so restore! can tell which children
  # were archived by this cascade (and must come back) from children that were
  # archived individually beforehand (and must stay archived).
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

  def ensure_default_dean_step!
    ReviewRole.ensure_system_roles!
    hierarchy_steps.find_or_create_by!(review_role: ReviewRole.dean) do |step|
      step.position = 1
      step.can_raise_on_behalf = false
    end
  end
end
