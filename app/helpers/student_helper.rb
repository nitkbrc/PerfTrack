module StudentHelper
  STATUS_BADGES = {
    "submitted" => "bg-blue-100 text-blue-700",
    "supervisor_approved" => "bg-amber-100 text-amber-700",
    "supervisor_reverted" => "bg-orange-100 text-orange-700",
    "dean_approved" => "bg-green-100 text-green-700",
    "dean_reverted" => "bg-orange-100 text-orange-700",
    "rejected" => "bg-red-100 text-red-700"
  }.freeze

  # Unambiguous history wording — "Supervisor initiate" reads like the student
  # submitted it; spell out who did what instead.
  HISTORY_LABELS = {
    "submit" => "Submitted by student",
    "resubmit" => "Edited & resubmitted by student",
    "supervisor_initiate" => "Raised by supervisor on the student's behalf",
    "supervisor_approve" => "Approved & forwarded to dean by supervisor",
    "supervisor_reforward" => "Clarified & re-forwarded to dean by supervisor",
    "supervisor_revert" => "Reverted to student by supervisor",
    "supervisor_reject" => "Rejected by supervisor",
    "dean_approve" => "Approved by dean — points awarded",
    "dean_revert" => "Sent back to supervisor by dean",
    "dean_reject" => "Rejected by dean"
  }.freeze

  def status_badge(request)
    classes = STATUS_BADGES.fetch(request.status, "bg-slate-100 text-slate-700")
    tag.span request_status_label(request),
             class: "scats-status-badge #{classes}"
  end

  def request_status_label(request)
    latest = request.req_histories.max_by(&:created_at)
    return request.status.humanize unless latest

    actor_name = latest.actor.name.presence || latest.actor.email

    case latest.action
    when "submit" then "Submitted"
    when "resubmit" then "Resubmitted"
    when "supervisor_initiate" then "Raised by #{actor_name}"
    when "supervisor_approve" then "Approved by #{actor_name}"
    when "supervisor_reforward" then "Re-forwarded by #{actor_name}"
    when "supervisor_revert" then "Reverted by #{actor_name}"
    when "supervisor_reject" then "Rejected by #{actor_name}"
    when "dean_approve" then "Approved by #{actor_name}"
    when "dean_revert" then "Sent back by #{actor_name}"
    when "dean_reject" then "Rejected by #{actor_name}"
    else request.status.humanize
    end
  end

  def history_label(action)
    HISTORY_LABELS.fetch(action, action.humanize)
  end
end
