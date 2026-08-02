# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  # Unknown policy queries (e.g. custom controller actions) deny instead of
  # raising Pundit::NotDefinedError and dumping a Rails error page.
  def method_missing(method_name, *args, &block)
    return false if query_method?(method_name)

    super
  end

  def respond_to_missing?(method_name, include_private = false)
    query_method?(method_name) || super
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end

  private

  def query_method?(method_name)
    method_name.to_s.end_with?("?")
  end
end
