class AchievementRequest < ApplicationRecord
  belongs_to :student
  belongs_to :category

  has_many :req_histories

  enum :status, { submitted: "submitted", supervisor_approved: "supervisor_approved",
                  supervisor_reverted: "supervisor_reverted", dean_approved: "dean_approved",
                  dean_reverted: "dean_reverted", rejected: "rejected" }
end
