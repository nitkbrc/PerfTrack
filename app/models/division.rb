class Division < ApplicationRecord
  belongs_to :dean, class_name: "User", foreign_key: :dean_user_id

  has_many :sub_divisions

  enum :div_type, { positive: "positive", negative: "negative" }
end
