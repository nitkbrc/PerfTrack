# frozen_string_literal: true

class AchievementRequestPolicy < ApplicationPolicy
  # Capacity checks (TRD section 5): always the FK relationship, never a role
  # string — "supervisor" and "dean" aren't role values.
  def review?
    user.faculty? && record.category.sub_division.supervisor_user_id == user.id
  end

  def dean_decide?
    user.faculty? && record.category.sub_division.division.dean_user_id == user.id
  end
end
