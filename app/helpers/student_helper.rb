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
    "supervisor_revise" => "Revised by supervisor after dean feedback",
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
    actor = history_actor_with_role(latest.action, actor_name)

    case latest.action
    when "submit" then "Submitted"
    when "resubmit" then "Resubmitted"
    when "supervisor_initiate" then "Raised by #{actor}"
    when "supervisor_revise" then "Revised by #{actor}"
    when "supervisor_approve" then "Approved by #{actor}"
    when "supervisor_reforward" then "Re-forwarded by #{actor}"
    when "supervisor_revert" then "Reverted by #{actor}"
    when "supervisor_reject" then "Rejected by #{actor}"
    when "dean_approve" then "Approved by #{actor}"
    when "dean_revert" then "Sent back by #{actor}"
    when "dean_reject" then "Rejected by #{actor}"
    else request.status.humanize
    end
  end

  def history_label(action)
    HISTORY_LABELS.fetch(action, action.humanize)
  end

  # Short past-tense verb for "You {verb} {title} on {date}" review-history rows.
  def review_history_verb(action)
    {
      "supervisor_initiate" => "raised",
      "supervisor_revise" => "revised",
      "supervisor_approve" => "approved",
      "supervisor_reforward" => "re-forwarded",
      "supervisor_revert" => "reverted",
      "supervisor_reject" => "rejected",
      "dean_approve" => "approved",
      "dean_revert" => "sent back",
      "dean_reject" => "rejected"
    }.fetch(action, action.to_s.tr("_", " "))
  end

  # Net-new: icon + soft colors for supervisor/dean Review history rows.
  # Does not touch STATUS_BADGES / status_badge / .scats-status-badge.
  def review_history_style(action)
    case action.to_s
    when /\A.+_approve\z/
      { icon: "check_circle", wrap: "bg-success-soft text-success", label: "Approved" }
    when "supervisor_reforward"
      { icon: "forward", wrap: "bg-info-soft text-info", label: "Forwarded" }
    when "supervisor_revise"
      { icon: "edit", wrap: "bg-warning-soft text-warning", label: "Revised" }
    when "supervisor_initiate"
      { icon: "flag", wrap: "bg-violet-100 text-violet-800", label: "Raised" }
    when /\A.+_revert\z/
      { icon: "undo", wrap: "bg-orange-100 text-orange-700", label: "Reverted" }
    when /\A.+_reject\z/
      { icon: "cancel", wrap: "bg-danger-soft text-danger", label: "Rejected" }
    else
      { icon: "history", wrap: "bg-slate-100 text-slate-600", label: action.to_s.humanize }
    end
  end

  private

  def history_actor_with_role(action, actor_name)
    role = case action.to_s
    when /\Adean_/ then "Dean"
    when /\Asupervisor_/ then "Supervisor"
    when "submit", "resubmit" then "Student"
    end
    role ? "#{actor_name} (#{role})" : actor_name
  end
end
