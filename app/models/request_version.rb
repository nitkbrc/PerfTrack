class RequestVersion < ApplicationRecord
  belongs_to :achievement_request
  belongs_to :category
  has_many :req_histories, dependent: :restrict_with_exception

  has_many_attached :proofs

  validates :version_number, presence: true,
                             uniqueness: { scope: :achievement_request_id }
  validates :title, presence: true
  validates :proofs, attached: true,
                     content_type: [ "image/png" ],
                     size: { less_than: 5.megabytes }
end
