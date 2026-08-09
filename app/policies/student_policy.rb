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

  # Manual create / CSV import for student accounts (faculty gated by ReviewRole).
  def create?
    user.can_create_students?
  end

  def new?
    create?
  end
end
