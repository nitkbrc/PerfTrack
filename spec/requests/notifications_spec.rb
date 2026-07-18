require "rails_helper"

RSpec.describe "Notifications", type: :request do
  let(:user)         { create(:user) }
  let!(:notification) { create(:notification, recipient: user, message: "You earned 20 points!") }

  before { sign_in user }

  describe "GET /notifications" do
    it "shows the user's notifications with an unread badge" do
      get notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("You earned 20 points!")
      expect(response.body).to match(/bg-red-600[^>]*>\s*1\s*</) # unread badge count
    end

    it "does not show other users' notifications" do
      create(:notification, message: "Someone else's news")

      get notifications_path

      expect(response.body).not_to include("Someone else&#39;s news")
    end
  end

  describe "PATCH /notifications/:id/mark_read" do
    it "marks the notification read" do
      patch mark_read_notification_path(notification)

      expect(response).to redirect_to(notifications_path(open: 1))
      expect(notification.reload.read).to be(true)
    end

    it "404s on another user's notification" do
      other = create(:notification)

      patch mark_read_notification_path(other)

      expect(response).to have_http_status(:not_found)
      expect(other.reload.read).to be(false)
    end
  end

  describe "PATCH /notifications/mark_all_read" do
    it "marks every unread notification read" do
      second = create(:notification, recipient: user)

      patch mark_all_read_notifications_path

      expect(notification.reload.read).to be(true)
      expect(second.reload.read).to be(true)
    end
  end
end
