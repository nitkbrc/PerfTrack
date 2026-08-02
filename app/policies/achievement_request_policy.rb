# frozen_string_literal: true

class AchievementRequestPolicy < ApplicationPolicy
  def index?
    student_with_profile?
  end

  def new?
    student_with_profile?
  end

  def create?
    student_with_profile?
  end

  def show?
    owning_student? || assigned_to_request_scope?
  end

  def resubmit?
    owning_student? && record.reverted?
  end

  def initiate?
    user.faculty? && raiseable_assignments.exists?
  end

  def dean_queue?
    user.faculty? && division_role_assignments.exists?
  end

  # Current reviewer for this request's live current_step.
  def review?
    user.faculty? && record.in_review? && record.current_reviewer&.id == user.id
  end

  def dean_decide?
    review?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.student? && user.student_profile
        scope.where(student: user.student_profile)
      elsif user.faculty? && user.role_assignments.exists?
        sub_ids = user.role_assignments.where.not(sub_division_id: nil).select(:sub_division_id)
        div_ids = user.role_assignments.where.not(division_id: nil).select(:division_id)
        scope.joins(category: { sub_division: :division }).where(
          "sub_divisions.id IN (?) OR divisions.id IN (?)",
          sub_ids, div_ids
        )
      else
        scope.none
      end
    end
  end

  private

  def student_with_profile?
    user.student? && user.student_profile.present?
  end

  def owning_student?
    student_with_profile? && record.student_id == user.student_profile.id
  end

  def assigned_to_request_scope?
    return false unless user.faculty?

    sub_id = record.category.sub_division_id
    div_id = record.category.sub_division.division_id
    user.role_assignments.exists?(sub_division_id: sub_id) ||
      user.role_assignments.exists?(division_id: div_id)
  end

  def raiseable_assignments
    user.role_assignments.joins(:review_role)
        .where(review_roles: { raiseable_on_behalf_eligible: true })
  end

  def division_role_assignments
    user.role_assignments.joins(:review_role).merge(ReviewRole.scope_division)
  end
end
