class NotificationPolicy < ApplicationPolicy
  # Every signed-in user has a bell; the scope keeps it to their own rows.
  def index?
    user.present?
  end

  def mark_read?
    record.recipient_id == user.id
  end

  def mark_all_read?
    user.present?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(recipient: user)
    end
  end
end
