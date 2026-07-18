class AchievementRequest < ApplicationRecord
  belongs_to :student
  belongs_to :category

  has_many :req_histories

  has_many_attached :proofs

  validates :title, presence: true

  validates :proofs, attached: true,
                     content_type: [ "image/png" ],
                     size: { less_than: 5.megabytes }

  enum :status, { submitted: "submitted", supervisor_approved: "supervisor_approved",
                  supervisor_reverted: "supervisor_reverted", dean_approved: "dean_approved",
                  dean_reverted: "dean_reverted", rejected: "rejected" }

  # Path A submission: the request and its first history row are created in one
  # transaction so neither can exist without the other (PRD section 7).
  def self.submit!(student:, actor:, attrs:)
    transaction do
      request = create!(attrs.merge(student: student, status: :submitted))
      request.req_histories.create!(actor: actor, action: "submit", to_status: "submitted")
      request
    end
  end

  # Path B: the supervisor creating the request is itself the review step, so it
  # skips submitted; the first history row records the supervisor as originator.
  def self.supervisor_initiate!(student:, actor:, attrs:)
    transaction do
      request = create!(attrs.merge(student: student, status: :supervisor_approved))
      request.req_histories.create!(actor: actor, action: "supervisor_initiate",
                                    to_status: "supervisor_approved")
      request
    end
  end

  # Every review transition writes its history row in the same transaction as
  # the status change (PRD section 6 — auditability).
  def transition!(to:, actor:, action:, comment: nil, reason_template: nil)
    transaction do
      from = status
      update!(status: to)
      req_histories.create!(actor: actor, action: action, comment: comment,
                            reason_template: reason_template,
                            from_status: from, to_status: to.to_s)
    end
  end

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
