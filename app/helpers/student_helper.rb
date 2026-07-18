module StudentHelper
  STATUS_BADGES = {
    "submitted" => "bg-blue-100 text-blue-700",
    "supervisor_approved" => "bg-amber-100 text-amber-700",
    "supervisor_reverted" => "bg-orange-100 text-orange-700",
    "dean_approved" => "bg-green-100 text-green-700",
    "dean_reverted" => "bg-orange-100 text-orange-700",
    "rejected" => "bg-red-100 text-red-700"
  }.freeze

  def status_badge(status)
    classes = STATUS_BADGES.fetch(status, "bg-slate-100 text-slate-700")
    tag.span status.humanize, class: "rounded-full px-2 py-0.5 text-xs font-semibold #{classes}"
  end

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

  def history_label(action)
    HISTORY_LABELS.fetch(action, action.humanize)
  end
end
