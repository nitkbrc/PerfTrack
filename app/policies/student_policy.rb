class StudentPolicy < ApplicationPolicy
  # Every faculty member (assigned or not) and admins can browse the
  # student directory with scores; students cannot see each other.
  def index?
    user.faculty? || user.admin?
  end

  def show?
    index?
  end
end
