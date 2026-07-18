class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  # No :registerable — accounts are created by admins only (PRD section 3).
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  enum :role, { admin: "admin", faculty: "faculty", student: "student" }

  has_one :student_profile, class_name: "Student"
  accepts_nested_attributes_for :student_profile
  has_many :deaned_divisions, class_name: "Division", foreign_key: :dean_user_id
  has_many :supervised_sub_divisions, class_name: "SubDivision", foreign_key: :supervisor_user_id
  has_many :req_histories, foreign_key: :actor_id
  has_many :notifications, foreign_key: :recipient_id, dependent: :destroy
end
