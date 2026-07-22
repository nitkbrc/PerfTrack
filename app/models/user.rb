class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  # No :registerable — accounts are created by admins only (PRD section 3).
  # No :recoverable — password reset via email is disabled; admins set temporary passwords.
  devise :database_authenticatable, :rememberable, :validatable

  enum :role, { admin: "admin", faculty: "faculty", student: "student" }

  has_one_attached :photo

  validates :phone, :address, presence: true
  validates :photo, attached: true,
                    content_type: [ "image/png", "image/jpeg" ],
                    size: { less_than: 5.megabytes }

  has_one :student_profile, class_name: "Student"
  accepts_nested_attributes_for :student_profile
  has_many :deaned_divisions, class_name: "Division", foreign_key: :dean_user_id
  has_many :supervised_sub_divisions, class_name: "SubDivision", foreign_key: :supervisor_user_id
  has_many :req_histories, foreign_key: :actor_id
  has_many :notifications, foreign_key: :recipient_id, dependent: :destroy

  # Faculty who may be assigned as a division dean: not already deaning a
  # division (unique index on divisions.dean_user_id) and not supervising a
  # sub-division (mutual exclusivity, TRD section 6). `keep_user_id` keeps the
  # record's current dean selectable on edit forms.
  def self.eligible_deans(keep_user_id = nil)
    taken = Division.select(:dean_user_id)
    taken = taken.where.not(dean_user_id: keep_user_id) if keep_user_id
    faculty.where.not(id: taken).where.not(id: SubDivision.select(:supervisor_user_id))
  end

  # Faculty who may supervise a sub-division: anyone who isn't a dean.
  # (Supervising several sub-divisions is allowed.)
  def self.eligible_supervisors
    faculty.where.not(id: Division.select(:dean_user_id))
  end
end
