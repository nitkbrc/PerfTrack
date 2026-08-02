class Category < ApplicationRecord
  include Archivable

  belongs_to :sub_division

  has_many :achievement_requests

  PENDING_ARCHIVE_STATUSES = %w[in_review reverted].freeze

  def archive!(stamp = Time.current, actor: nil)
    transaction do
      update!(archived_at: stamp)
      reject_pending_requests!(actor: actor) if actor
    end
  end

  def restore!
    update!(archived_at: nil)
  end

  private

  def reject_pending_requests!(actor:)
    achievement_requests.where(status: PENDING_ARCHIVE_STATUSES).find_each do |request|
      request.reject!(
        actor: actor,
        action: "auto_reject_archived",
        comment: "Automatically rejected — category archived"
      )
    end
  end
end
