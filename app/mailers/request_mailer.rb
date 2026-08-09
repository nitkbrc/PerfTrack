class RequestMailer < ApplicationMailer
  # Student submit / resubmit → current reviewer (typically supervisor)
  def submitted_to_supervisor(request, actor:, recipient: nil)
    setup_request_mail(request, actor: actor, recipient: recipient || request.current_reviewer)
    fresh = request.current_version&.version_number.to_i <= 1
    subject = if fresh
      "New SCATS request awaiting your review"
    else
      "Resubmitted SCATS request awaiting your review"
    end
    mail(to: @recipient.email, subject: subject)
  end

  # Path B supervisor raise → next reviewer (typically dean)
  def raised_on_behalf(request, actor:, recipient: nil)
    setup_request_mail(request, actor: actor, recipient: recipient || request.current_reviewer)
    mail(to: @recipient.email, subject: "Supervisor-raised SCATS request awaiting your review")
  end

  # Path B supervisor raise → student (informational)
  def raised_on_your_behalf(request, actor:)
    setup_request_mail(request, actor: actor, recipient: request.student.user)
    mail(to: @recipient.email, subject: "A supervisor raised a SCATS request on your behalf")
  end

  # Advance → next reviewer
  def forwarded_to_dean(request, actor:, is_reforward: false, recipient: nil)
    @is_reforward = is_reforward
    setup_request_mail(request, actor: actor, recipient: recipient || request.current_reviewer)
    subject = if is_reforward
      "Clarified SCATS request re-forwarded for your review"
    else
      "SCATS request forwarded for your review"
    end
    mail(to: @recipient.email, subject: subject)
  end

  def reverted_to_supervisor(request, actor:, comment: nil, recipient: nil)
    setup_request_mail(request, actor: actor,
                       recipient: recipient || request.current_reviewer,
                       comment: comment)
    mail(to: @recipient.email, subject: "Clarification requested on a SCATS request")
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

  # Hierarchy template / reattach remapped an in-flight request onto a new role.
  def hierarchy_reassigned_to_reviewer(request, actor:, recipient:, landing_role:)
    @landing_role = landing_role
    setup_request_mail(request, actor: actor, recipient: recipient)
    mail(to: @recipient.email, subject: "SCATS request reassigned to your review after a hierarchy change")
  end

  def hierarchy_reassigned_to_student(request, actor:, landing_role:, reviewer: nil)
    @landing_role = landing_role
    @reviewer = reviewer
    setup_request_mail(request, actor: actor, recipient: request.student.user)
    mail(to: @recipient.email, subject: "Your SCATS request review path was updated")
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

  def timeline_url_for(recipient, request)
    if recipient.id == request.student.user_id
      student_achievement_request_url(request)
    elsif recipient.role_assignments.joins(:review_role).merge(ReviewRole.scope_division).exists?
      dean_achievement_request_url(request)
    elsif recipient.role_assignments.joins(:review_role).merge(ReviewRole.scope_sub_division).exists?
      supervisor_achievement_request_url(request)
    else
      faculty_root_url
    end
  end
end
