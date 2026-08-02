# frozen_string_literal: true

class UserPolicy < AdminOnlyPolicy
  def show?
    user == record || user.admin?
  end

  # Own-profile updates; field-level Permission gates live in ProfilesController.
  def update?
    user == record || user.admin?
  end
end
