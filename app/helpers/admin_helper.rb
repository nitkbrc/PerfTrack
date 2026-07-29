module AdminHelper
  def admin_modal_frame_data
    { turbo_frame: "modal" }
  end

  def admin_label_classes
    "block text-sm font-medium text-text-main"
  end

  def admin_input_classes
    "mt-1 block h-10 w-full rounded-md border border-border-subtle bg-surface-white px-3 py-2 text-sm text-text-main shadow-sm " \
    "placeholder:text-text-muted focus:border-primary focus:outline-none focus:ring-2 focus:ring-secondary-container/40"
  end

  def admin_primary_button_classes
    "scats-primary-button"
  end

  def admin_link_classes
    "text-sm font-medium text-primary hover:text-secondary"
  end

  def admin_back_link_classes
    "scats-secondary-button"
  end

  def admin_secondary_button_classes
    "scats-secondary-button"
  end

  def admin_warning_button_classes
    "inline-flex cursor-pointer items-center gap-1.5 rounded-md border border-amber-400/70 " \
    "bg-amber-50 px-3 py-1.5 text-sm font-semibold text-amber-800 shadow-sm " \
    "transition hover:bg-amber-100 " \
    "focus:outline-none focus:ring-2 focus:ring-amber-300 focus:ring-offset-2"
  end

  def admin_delete_classes
    "scats-danger-button px-2.5 py-1 text-xs"
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
             class: "scats-badge scats-badge-neutral ml-2"
  end

  def division_type_badge(division)
    if division.positive?
      tag.span division.div_type, class: "scats-badge scats-badge-success"
    else
      tag.span division.div_type, class: "scats-badge scats-badge-danger"
    end
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

  def user_role_badge_classes(label = nil)
    case label.to_s.downcase
    when "student" then "scats-badge scats-badge-info"
    when "dean" then "scats-badge scats-badge-dean"
    when "supervisor" then "scats-badge scats-badge-warning"
    when "admin" then "scats-badge scats-badge-admin"
    when "faculty" then "scats-badge scats-badge-neutral"
    else "scats-badge scats-badge-neutral"
    end
  end
end
