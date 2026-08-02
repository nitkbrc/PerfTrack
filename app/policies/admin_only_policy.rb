# frozen_string_literal: true

# Base for resources only admins manage (TRD section 5).
class AdminOnlyPolicy < ApplicationPolicy
  def index?
    user.admin?
  end

  def show?
    user.admin?
  end

  def create?
    user.admin?
  end

  def update?
    user.admin?
  end

  def destroy?
    user.admin?
  end

  def archive?
    user.admin?
  end

  def restore?
    user.admin?
  end

  # Custom member/collection actions (move_up, bulk_apply, …) inherit admin gate
  # so new routes don't crash with Pundit::NotDefinedError.
  def method_missing(method_name, *args, &block)
    return user.admin? if query_method?(method_name)

    super
  end

  def respond_to_missing?(method_name, include_private = false)
    query_method?(method_name) || super
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.admin? ? scope.all : scope.none
    end
  end
end
