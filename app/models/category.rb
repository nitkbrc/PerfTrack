class Category < ApplicationRecord
  belongs_to :sub_division

  has_many :achievement_requests
end
