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
end
