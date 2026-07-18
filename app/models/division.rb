class Division < ApplicationRecord
  include Archivable

  belongs_to :dean, class_name: "User", foreign_key: :dean_user_id

  has_many :sub_divisions

  enum :div_type, { positive: "positive", negative: "negative" }

  # The whole cascade shares one timestamp so restore! can tell which children
  # were archived by this cascade (and must come back) from children that were
  # archived individually beforehand (and must stay archived).
  def archive!
    transaction do
      stamp = Time.current
      update!(archived_at: stamp)
      sub_divisions.active.find_each { |sub_division| sub_division.archive!(stamp) }
    end
  end

  def restore!
    transaction do
      stamp = archived_at
      update!(archived_at: nil)
      sub_divisions.where(archived_at: stamp).find_each(&:restore!)
    end
  end

  # Backs the unique DB index so a duplicate dean re-renders the form with an
  # error instead of raising ActiveRecord::RecordNotUnique.
  validates :dean_user_id, uniqueness: { message: "is already the dean of another division" }
  validate :dean_is_not_a_supervisor

  private

  # Dean/Supervisor mutual exclusivity (TRD section 6) spans two tables,
  # so it can't be a DB constraint.
  def dean_is_not_a_supervisor
    if SubDivision.exists?(supervisor_user_id: dean_user_id)
      errors.add(:dean_user_id, "is already a supervisor of a sub-division")
    end
  end
end
