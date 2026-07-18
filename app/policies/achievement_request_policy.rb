# frozen_string_literal: true

class AchievementRequestPolicy < ApplicationPolicy
  # Path A submission: only students with a profile can create requests.
  def index?
    student_with_profile?
  end

  def new?
    student_with_profile?
  end

  def create?
    student_with_profile?
  end

  # The owning student, or the supervisor whose queue the request sits in.
  def show?
    owning_student? || review?
  end

  # Student edit + resubmit of a reverted request (PRD section 6 lifecycle).
  def resubmit?
    owning_student? && record.supervisor_reverted?
  end

  # Path B: any faculty member who supervises at least one sub-division.
  def initiate?
    user.faculty? && user.supervised_sub_divisions.exists?
  end

  # Capacity checks (TRD section 5): always the FK relationship, never a role
  # string — "supervisor" and "dean" aren't role values.
  def review?
    user.faculty? && record.category.sub_division.supervisor_user_id == user.id
  end

  def dean_decide?
    user.faculty? && record.category.sub_division.division.dean_user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.student? && user.student_profile
        scope.where(student: user.student_profile)
      elsif user.faculty? && user.supervised_sub_divisions.exists?
        scope.joins(category: :sub_division)
             .where(sub_divisions: { supervisor_user_id: user.id })
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
end
