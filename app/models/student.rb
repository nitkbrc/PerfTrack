class Student < ApplicationRecord
  belongs_to :user
  belongs_to :department

  has_many :achievement_requests

  validates :usn, presence: true, uniqueness: true
end
