# frozen_string_literal: true

class UserPolicy < AdminOnlyPolicy
  def show?
    user == record || user.admin?
  end
end
