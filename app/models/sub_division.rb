class SubDivision < ApplicationRecord
  include Archivable

  belongs_to :division
  belongs_to :supervisor, class_name: "User", foreign_key: :supervisor_user_id

  has_many :categories
  has_many :active_categories, -> { active }, class_name: "Category"

  validate :supervisor_is_not_a_dean

  # Same shared-timestamp cascade as Division#archive! (see comment there).
  def archive!(stamp = Time.current)
    transaction do
      update!(archived_at: stamp)
      categories.active.find_each { |category| category.archive!(stamp) }
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

  # Mirror image of Division#dean_is_not_a_supervisor (TRD section 6).
  def supervisor_is_not_a_dean
    if Division.exists?(dean_user_id: supervisor_user_id)
      errors.add(:supervisor_user_id, "is already a dean of a division")
    end
  end
end
