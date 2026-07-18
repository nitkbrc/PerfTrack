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
end
