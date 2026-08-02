class SubDivision < ApplicationRecord
  include Archivable

  belongs_to :division

  has_many :categories
  has_many :active_categories, -> { active }, class_name: "Category"
  has_many :hierarchy_steps, dependent: :destroy
  has_many :role_assignments, dependent: :destroy

  after_create :ensure_default_supervisor_step!

  def supervisor
    RoleAssignment.holder_for(review_role: ReviewRole.supervisor, sub_division: self)
  end

  def supervisor_assignment
    role_assignments.find_by(review_role: ReviewRole.supervisor)
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

  def ensure_default_supervisor_step!
    ReviewRole.ensure_system_roles!
    hierarchy_steps.find_or_create_by!(review_role: ReviewRole.supervisor) do |step|
      step.position = 1
      step.can_raise_on_behalf = true
    end
  end
end
