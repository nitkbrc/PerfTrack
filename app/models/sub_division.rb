class SubDivision < ApplicationRecord
  belongs_to :division
  belongs_to :supervisor, class_name: "User", foreign_key: :supervisor_user_id

  has_many :categories
end
