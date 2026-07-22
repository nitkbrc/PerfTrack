class DeanApprovalNotificationJob < ApplicationJob
  queue_as :default

  def perform(achievement_request_id)
    request = AchievementRequest.includes(:req_histories).find_by(id: achievement_request_id)
    # The request may have been deleted, or its status changed, between enqueue
    # and execution; only notify for a still-approved request.
    return unless request&.dean_approved?

    Notification.find_or_create_by!(recipient: request.student.user,
                                    achievement_request: request) do |notification|
      notification.message = build_message(request)
    end
  end

  private

  def build_message(request)
    points = request.points_awarded
    positive = points.positive?
    direction = positive ? "Positive" : "Negative"
    verb = positive ? "added to" : "deducted from"
    amount = "#{points.abs} point#{"s" unless points.abs == 1}"
    suffix = "#{direction}: #{amount} #{verb} your record."

    "#{opening_sentence(request, positive)} #{suffix}"
  end

  def opening_sentence(request, positive)
    title = request.title

    if request.student_initiated?
      if positive
        "Your request \"#{title}\" was approved by the dean."
      else
        "Your request \"#{title}\" was verified by the dean."
      end
    elsif positive
      "A request raised by your supervisor for \"#{title}\" was approved by the dean."
    else
      "A conduct record raised by your supervisor for \"#{title}\" was verified by the dean."
    end
  end
end
