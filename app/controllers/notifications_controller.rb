class NotificationsController < ApplicationController
  before_action :authenticate_user!

  # Rendered inside the bell's Turbo Frame, so updates never reload the page.
  def index
    authorize Notification
    @notifications = policy_scope(Notification)
                       .includes(:achievement_request)
                       .order(created_at: :desc)
                       .limit(20)
    @unread_count = policy_scope(Notification).unread.count
  end

  def mark_read
    notification = authorize policy_scope(Notification).find(params[:id]), :mark_read?
    notification.update!(read: true)
    redirect_to notifications_path(open: 1)
  end

  def mark_all_read
    authorize Notification, :mark_all_read?
    policy_scope(Notification).unread.update_all(read: true, updated_at: Time.current)
    redirect_to notifications_path(open: 1)
  end
end
