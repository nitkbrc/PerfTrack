class StudentPolicy < ApplicationPolicy
  # Every faculty member (assigned or not) can browse the student directory
  # with scores. Admins manage structure and accounts, not student records;
  # students cannot see each other.
  def index?
    user.faculty?
  end

  def show?
    index?
  end
end
