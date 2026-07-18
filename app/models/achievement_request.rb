class AchievementRequest < ApplicationRecord
  belongs_to :student
  belongs_to :category

  has_many :req_histories

  has_many_attached :proofs

  validates :proofs, attached: true,
                     content_type: [ "image/png" ],
                     size: { less_than: 5.megabytes }

  enum :status, { submitted: "submitted", supervisor_approved: "supervisor_approved",
                  supervisor_reverted: "supervisor_reverted", dean_approved: "dean_approved",
                  dean_reverted: "dean_reverted", rejected: "rejected" }

  # Dean approval snapshots the signed point value in the same transaction as
  # the status change (TRD section 6), so later category.points edits never
  # retroactively change an already-verified record.
  def dean_approve!
    transaction do
      sign = category.sub_division.division.positive? ? 1 : -1
      update!(status: :dean_approved, points_awarded: category.points * sign)
    end
  end
end
