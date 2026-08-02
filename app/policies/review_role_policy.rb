# frozen_string_literal: true

class ReviewRolePolicy < AdminOnlyPolicy
  def destroy?
    user.admin? && !record.system_role?
  end
end
