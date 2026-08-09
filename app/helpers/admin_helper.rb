module AdminHelper
  def settings_hub_cards
    [
      {
        title: "Review roles",
        description: "Define system and custom roles used in review chains.",
        path: admin_review_roles_path,
        icon: "badge"
      },
      {
        title: "Role assignments",
        description: "Assign faculty to roles for each division or sub-division.",
        path: admin_role_assignments_path,
        icon: "group"
      },
      {
        title: "Hierarchy templates",
        description: "Shared review chains for divisions and sub-divisions.",
        path: admin_hierarchies_path,
        icon: "account_tree"
      },
      {
        title: "Role permissions",
        description: "Profile self-edit fields and which review roles may add students.",
        path: role_permissions_admin_settings_path,
        icon: "manage_accounts"
      },
      {
        title: "Score scale constant",
        description: "Adjust how net points map to the 0–10 overall score.",
        path: score_scale_admin_settings_path,
        icon: "tune"
      }
    ]
  end

  PROFILE_PERMISSION_FIELDS = {
    "edit_own_phone" => {
      label: "Phone number",
      description: "Change the contact number shown on their profile.",
      icon: "call"
    },
    "edit_own_address" => {
      label: "Address",
      description: "Update residential or correspondence address details.",
      icon: "home"
    },
    "edit_own_photo" => {
      label: "Profile photo",
      description: "Upload or replace their avatar image.",
      icon: "photo_camera"
    }
  }.freeze

  PROFILE_PERMISSION_ROLES = {
    "student" => {
      label: "Students",
      subtitle: "Self-service edits on the student profile",
      icon: "school",
      header: "from-teal-50 to-white",
      icon_bg: "bg-teal-100 text-teal-700",
      accent: "text-teal-700",
      ring: "ring-teal-100"
    },
    "faculty" => {
      label: "Faculty",
      subtitle: "Self-service edits on the faculty profile",
      icon: "person",
      header: "from-blue-50 to-white",
      icon_bg: "bg-blue-100 text-blue-700",
      accent: "text-blue-700",
      ring: "ring-blue-100"
    }
  }.freeze

  def profile_permission_field(action)
    PROFILE_PERMISSION_FIELDS.fetch(action.to_s) do
      {
        label: action.to_s.sub(/\Aedit_own_/, "").humanize,
        description: "Control whether users can edit this profile field.",
        icon: "tune"
      }
    end
  end

  def profile_permission_role(role)
    PROFILE_PERMISSION_ROLES.fetch(role.to_s) do
      {
        label: role.to_s.humanize,
        subtitle: "Self-service profile edits",
        icon: "person",
        header: "from-slate-50 to-white",
        icon_bg: "bg-slate-100 text-slate-600",
        accent: "text-slate-700",
        ring: "ring-slate-100"
      }
    end
  end

  def profile_permission_summary(permissions)
    enabled = permissions.count(&:enabled?)
    total = permissions.size
    { enabled: enabled, total: total, locked: total - enabled }
  end

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

  def admin_restore_button_classes
    "inline-flex cursor-pointer items-center gap-1.5 rounded-lg border border-emerald-200 " \
    "bg-emerald-50 px-3 py-1.5 text-sm font-semibold text-emerald-800 shadow-sm " \
    "transition hover:bg-emerald-100 " \
    "focus:outline-none focus:ring-2 focus:ring-emerald-300 focus:ring-offset-2"
  end

  def admin_permanent_delete_button_classes
    "inline-flex cursor-pointer items-center gap-1.5 rounded-lg border border-red-200 " \
    "bg-white px-3 py-1.5 text-sm font-semibold text-red-700 shadow-sm " \
    "transition hover:bg-red-50 " \
    "focus:outline-none focus:ring-2 focus:ring-red-200 focus:ring-offset-2"
  end

  def admin_delete_classes
    "inline-flex cursor-pointer items-center justify-center rounded-md px-2.5 py-1 text-xs font-semibold " \
    "text-danger transition hover:bg-danger-soft " \
    "focus:outline-none focus:ring-2 focus:ring-danger/25 focus:ring-offset-1"
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

  REVIEW_ROLE_BADGE_PALETTE = [
    "bg-slate-800 text-white",
    "bg-blue-600 text-white",
    "bg-teal-700 text-white",
    "bg-indigo-600 text-white",
    "bg-cyan-700 text-white",
    "bg-violet-600 text-white"
  ].freeze

  REVIEW_ROLE_BADGE_KNOWN = {
    "Dean" => "bg-blue-600 text-white",
    "Supervisor" => "bg-teal-700 text-white",
    "Associate Dean" => "bg-indigo-600 text-white"
  }.freeze

  def review_role_initials(name)
    parts = name.to_s.split.reject(&:blank?)
    return "?" if parts.empty?

    if parts.length == 1
      parts.first.first(2).upcase
    else
      "#{parts.first[0]}#{parts.last[0]}".upcase
    end
  end

  def review_role_badge_classes(name)
    key = name.to_s.strip
    REVIEW_ROLE_BADGE_KNOWN.fetch(key) do
      digest = key.each_byte.sum
      REVIEW_ROLE_BADGE_PALETTE[digest % REVIEW_ROLE_BADGE_PALETTE.size]
    end
  end

  # Compact ordered role names for hierarchy previews, e.g. "Supervisor → Dean".
  def hierarchy_step_labels(steps)
    Array(steps).sort_by(&:position).map { |step| step.review_role&.name }.compact
  end

  def hierarchy_chain_summary(steps)
    labels = hierarchy_step_labels(steps)
    return "No steps configured" if labels.empty?

    labels.join(" → ")
  end

  # Display labels for the admin users Role column. Faculty show actual
  # ReviewRole names from assignments (Dean, Supervisor, or admin-created roles).
  def user_role_labels(user)
    return [ user.role.titleize ] unless user.faculty?

    names = user.role_assignments.filter_map { |a| a.review_role&.name }.uniq
    names.presence || [ "Faculty" ]
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
