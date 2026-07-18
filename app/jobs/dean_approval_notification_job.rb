class DeanApprovalNotificationJob < ApplicationJob
  queue_as :default

  def perform(achievement_request_id)
    request = AchievementRequest.find_by(id: achievement_request_id)
    # The request may have been deleted, or its status changed, between enqueue
    # and execution; only notify for a still-approved request.
    return unless request&.dean_approved?

    points = request.points_awarded
    direction = points.positive? ? "Positive" : "Negative"
    message = "Your request \"#{request.title}\" was approved by the dean. " \
              "#{direction}: #{points.abs} point#{"s" unless points.abs == 1} " \
              "#{points.positive? ? "added to" : "deducted from"} your record."

    Notification.create!(recipient: request.student.user,
                         achievement_request: request,
                         message: message)
  end
end
