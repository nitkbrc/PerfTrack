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

  has_one :student_profile, class_name: "Student", dependent: :destroy
  accepts_nested_attributes_for :student_profile
  has_many :role_assignments, dependent: :restrict_with_exception
  # History rows keep an audit trail; block account deletion while this user is still
  # recorded as an actor on any remaining request (own student requests cascade away first).
  has_many :req_histories, foreign_key: :actor_id, dependent: :restrict_with_exception
  has_many :notifications, foreign_key: :recipient_id, dependent: :destroy

  def assigned_divisions
    Division.where(id: role_assignments.where.not(division_id: nil).select(:division_id))
  end

  def assigned_sub_divisions
    SubDivision.where(id: role_assignments.where.not(sub_division_id: nil).select(:sub_division_id))
  end

  # Convenience aliases used by older call sites / navigation.
  alias_method :deaned_divisions, :assigned_divisions
  alias_method :supervised_sub_divisions, :assigned_sub_divisions

  def self.eligible_for_role(review_role, keep_user_id: nil)
    ReviewRole.ensure_system_roles!
    scope = faculty
    occupied = RoleAssignment.joins(:review_role)

    if review_role.scope_division?
      taken_ids = if keep_user_id
        RoleAssignment.where.not(user_id: keep_user_id).select(:user_id)
      else
        occupied.select(:user_id)
      end
      scope.where.not(id: taken_ids)
    else
      conflicting = if keep_user_id
        occupied.where.not(review_role_id: review_role.id)
                .where.not(user_id: keep_user_id).select(:user_id)
      else
        occupied.where.not(review_role_id: review_role.id).select(:user_id)
      end
      scope.where.not(id: conflicting)
    end
  end
end
