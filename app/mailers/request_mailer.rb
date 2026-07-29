class RequestMailer < ApplicationMailer
  # Student submit / resubmit → sub-division supervisor
  def submitted_to_supervisor(request, actor:)
    setup_request_mail(request, actor: actor, recipient: request_supervisor(request))
    fresh = request.current_version&.version_number.to_i <= 1
    subject = if fresh
      "New SCATS request awaiting your review"
    else
      "Resubmitted SCATS request awaiting your review"
    end
    mail(to: @recipient.email, subject: subject)
  end

  # Path B supervisor raise → division dean
  def raised_on_behalf(request, actor:)
    setup_request_mail(request, actor: actor, recipient: request_dean(request))
    mail(to: @recipient.email, subject: "Supervisor-raised SCATS request awaiting your review")
  end

  # Supervisor approve / reforward → dean
  def forwarded_to_dean(request, actor:, is_reforward: false)
    @is_reforward = is_reforward
    setup_request_mail(request, actor: actor, recipient: request_dean(request))
    subject = if is_reforward
      "Clarified SCATS request re-forwarded for your review"
    else
      "SCATS request forwarded for your review"
    end
    mail(to: @recipient.email, subject: subject)
  end

  def reverted_to_supervisor(request, actor:, comment: nil)
    setup_request_mail(request, actor: actor, recipient: request_supervisor(request), comment: comment)
    mail(to: @recipient.email, subject: "Dean requested clarification on a SCATS request")
  end

  def reverted_to_student(request, actor:, comment: nil)
    setup_request_mail(request, actor: actor, recipient: request.student.user, comment: comment)
    mail(to: @recipient.email, subject: "Your SCATS request was returned for revision")
  end

  def approved_notification(request, actor:, recipient:)
    setup_request_mail(request, actor: actor, recipient: recipient)
    mail(to: @recipient.email, subject: "SCATS request approved")
  end

  def rejected_notification(request, actor:, recipient:, comment: nil)
    setup_request_mail(request, actor: actor, recipient: recipient, comment: comment)
    mail(to: @recipient.email, subject: "SCATS request rejected")
  end

  private

  def setup_request_mail(request, actor:, recipient:, comment: nil)
    @request = request
    @actor = actor
    @recipient = recipient
    @student = request.student
    @version = request.current_version
    @comment = comment
    @timeline_url = timeline_url_for(recipient, request)
  end

  def request_supervisor(request)
    request.category.sub_division.supervisor
  end

  def request_dean(request)
    request.category.sub_division.division.dean
  end

  def timeline_url_for(recipient, request)
    if recipient.id == request.student.user_id
      student_achievement_request_url(request)
    elsif recipient.id == request.category.sub_division.supervisor_user_id
      supervisor_achievement_request_url(request)
    else
      dean_achievement_request_url(request)
    end
  end
end
