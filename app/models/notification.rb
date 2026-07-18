class Notification < ApplicationRecord
  belongs_to :recipient, class_name: "User"
  belongs_to :achievement_request

  validates :message, presence: true

  scope :unread, -> { where(read: false) }
end
