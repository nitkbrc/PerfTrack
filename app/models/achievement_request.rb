class AchievementRequest < ApplicationRecord
  belongs_to :student
  belongs_to :category

  has_many :req_histories
  has_many :notifications, dependent: :destroy

  has_many_attached :proofs

  validates :title, presence: true

  # Backend guard behind the picker filtering: archived (soft-deleted)
  # categories keep their existing requests but never accept new ones.
  validate :category_is_not_archived, on: :create

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

  # Path A vs Path B origin — the first history row is the source of truth.
  def student_initiated?
    req_histories.order(:created_at).first&.action == "submit"
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
  # the status change and its history row (TRD section 6), so later
  # category.points edits never retroactively change an already-verified record.
  def dean_approve!(actor:)
    transaction do
      sign = category.sub_division.division.positive? ? 1 : -1
      from = status
      update!(status: :dean_approved, points_awarded: category.points * sign)
      req_histories.create!(actor: actor, action: "dean_approve",
                            from_status: from, to_status: "dean_approved")
    end
    # Enqueued after the transaction commits so the job never sees a rolled-back
    # approval (PRD section 8 — notify on verification).
    DeanApprovalNotificationJob.perform_later(id)
  end

  private

  def category_is_not_archived
    if category&.archived?
      errors.add(:category, "has been archived and no longer accepts new requests")
    end
  end
end
