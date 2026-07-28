module AdminHelper
  def admin_modal_frame_data
    { turbo_frame: "modal" }
  end

  def admin_label_classes
    "block text-sm font-medium text-slate-700"
  end

  def admin_input_classes
    "mt-1 block w-full rounded-md border border-[#DEE2E6] bg-white px-3 py-2 text-[#212529] shadow-sm " \
    "placeholder:text-[#6C757D] focus:border-[#000666] focus:outline-none focus:ring-2 focus:ring-[#668efe]/40"
  end

  def admin_primary_button_classes
    "cursor-pointer rounded-md bg-[#000666] px-4 py-2 text-sm font-semibold text-white shadow-sm " \
    "transition hover:bg-[#1a237e] focus:outline-none focus:ring-2 focus:ring-[#668efe] focus:ring-offset-2"
  end

  def admin_link_classes
    "text-sm font-medium text-[#000666] hover:text-[#1a237e]"
  end

  def admin_back_link_classes
    "inline-flex items-center gap-1.5 rounded-md border border-[#DEE2E6] bg-[#e0e0ff]/60 " \
    "px-3 py-1.5 text-sm font-semibold text-[#000666] shadow-sm transition " \
    "hover:border-[#000666]/30 hover:bg-[#e0e0ff] hover:text-[#000666] " \
    "focus:outline-none focus:ring-2 focus:ring-[#668efe] focus:ring-offset-2"
  end

  # Navy-tint pill for secondary card actions (Edit, Restore).
  def admin_secondary_button_classes
    "inline-flex cursor-pointer items-center gap-1.5 rounded-md border border-[#DEE2E6] " \
    "bg-[#e0e0ff]/70 px-3 py-1.5 text-sm font-semibold text-[#000666] shadow-sm " \
    "transition hover:scale-[1.02] hover:border-[#000666]/30 hover:bg-[#e0e0ff] " \
    "focus:outline-none focus:ring-2 focus:ring-[#668efe] focus:ring-offset-2"
  end

  # Amber warning pill for Archive — visually secondary to Edit.
  def admin_warning_button_classes
    "inline-flex cursor-pointer items-center gap-1.5 rounded-md border border-amber-400/70 " \
    "bg-amber-50 px-3 py-1.5 text-sm font-semibold text-amber-800 shadow-sm " \
    "transition hover:scale-[1.02] hover:bg-amber-100 " \
    "focus:outline-none focus:ring-2 focus:ring-amber-300 focus:ring-offset-2"
  end

  def admin_delete_classes
    "cursor-pointer text-sm font-medium text-red-600 hover:text-red-500"
  end

  def admin_archive_classes
    "cursor-pointer text-sm font-medium text-amber-600 hover:text-amber-500"
  end

  def admin_edit_action_label
    safe_join([ tag.span("✎", "aria-hidden": true), "Edit" ], " ")
  end

  def admin_archive_action_label
    safe_join([ tag.span("⧉", "aria-hidden": true), "Archive" ], " ")
  end

  def admin_restore_action_label
    safe_join([ tag.span("↺", "aria-hidden": true), "Restore" ], " ")
  end

  def archived_badge(record)
    tag.span "Archived #{record.archived_at.strftime('%d %b %Y')}",
             class: "ml-2 rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-500"
  end

  # Display labels for the admin users Role column. Faculty with dean/supervisor
  # assignments show those titles instead of plain "Faculty".
  def user_role_labels(user)
    return [ user.role.titleize ] unless user.faculty?

    labels = []
    labels << "Dean" if user.deaned_divisions.any?
    labels << "Supervisor" if user.supervised_sub_divisions.any?
    labels.presence || [ "Faculty" ]
  end

  def user_role_badge_classes
    "rounded-full bg-[#e0e0ff] px-2 py-0.5 text-xs font-semibold uppercase tracking-wide text-[#000666]"
  end
end
