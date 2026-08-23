module ApplicationHelper
  # ---------------------------------------------------------------------------
  # Ethos Score tiers (plan: six bands over 0–10 sigmoid scale)
  # ---------------------------------------------------------------------------
  ETHOS_TIERS = [
    { key: "gold",   name: "Gold",   min: 8.5,  max: 10.0 },
    { key: "silver", name: "Silver", min: 6.5,  max: 8.5  },
    { key: "bronze", name: "Bronze", min: 5.0,  max: 6.5  },
    { key: "orange", name: "Orange", min: 3.5,  max: 5.0  },
    { key: "red",    name: "Red",    min: 1.5,  max: 3.5  },
    { key: "black",  name: "Black",  min: 0.0,  max: 1.5  }
  ].freeze

  TIER_STYLES = {
    "gold"   => { badge: "bg-yellow-400/20 text-yellow-700 ring-yellow-400",   ring: "ring-yellow-400",   dot: "bg-yellow-400"   },
    "silver" => { badge: "bg-slate-300/30 text-slate-600 ring-slate-400",      ring: "ring-slate-400",    dot: "bg-slate-400"    },
    "bronze" => { badge: "bg-orange-300/20 text-orange-700 ring-orange-400",   ring: "ring-orange-400",   dot: "bg-orange-400"   },
    "orange" => { badge: "bg-orange-200/30 text-orange-600 ring-orange-300",   ring: "ring-orange-300",   dot: "bg-orange-400"   },
    "red"    => { badge: "bg-red-100 text-red-700 ring-red-400",               ring: "ring-red-400",      dot: "bg-red-500"      },
    "black"  => { badge: "bg-slate-900/10 text-slate-800 ring-slate-700",      ring: "ring-slate-700",    dot: "bg-slate-900"    }
  }.freeze

  def ethos_tier(score)
    tier = ETHOS_TIERS.find { |t| score >= t[:min] } || ETHOS_TIERS.last
    styles = TIER_STYLES[tier[:key]]
    tier.merge(styles)
  end

  # Compact score chip for faculty students list — uses ethos tier soft colors.
  # Separate from status_badge (frozen for student-dashboard status pills).
  SCORE_BADGE_CLASSES = {
    "gold"   => "bg-yellow-100 text-yellow-800",
    "silver" => "bg-slate-200 text-slate-700",
    "bronze" => "bg-orange-100 text-orange-800",
    "orange" => "bg-orange-50 text-orange-700",
    "red"    => "bg-red-100 text-red-700",
    "black"  => "bg-slate-800 text-white"
  }.freeze

  def score_badge(score)
    tier = ethos_tier(score.to_f)
    tag.span format("%.1f", score.to_f),
             class: "scats-badge tabular-nums #{SCORE_BADGE_CLASSES.fetch(tier[:key], 'scats-badge-neutral')}",
             title: "#{tier[:name]} tier"
  end

  # ---------------------------------------------------------------------------
  # Integrity Index: ratio of positive to total approved points (0–100).
  # Clean slate (no approved points) is 0 / 0, not a fake 100%.
  # ---------------------------------------------------------------------------
  def integrity_slices(student)
    pos = student.positive_total
    neg = student.negative_total.abs
    if pos.zero? && neg.zero?
      { achievement: 0, conduct: 0, empty: true }
    else
      achievement = ((100.0 * pos) / (pos + neg)).round
      { achievement: achievement, conduct: 100 - achievement, empty: false }
    end
  end

  def integrity_index(student)
    integrity_slices(student)[:achievement]
  end

  def integrity_risk(index, empty: false)
    if empty
      { label: "No data", classes: "bg-slate-100 text-slate-600" }
    elsif index >= 85
      { label: "Minimal Risk", classes: "bg-emerald-100 text-emerald-700" }
    elsif index >= 60
      { label: "Moderate Risk", classes: "bg-yellow-100 text-yellow-700" }
    else
      { label: "Elevated Risk", classes: "bg-red-100 text-red-700" }
    end
  end

  # Rotating auth/dashboard backgrounds — every jpg/jpeg/png/webp under
  # app/assets/images (including campus/). Drop new files there to use them.
  def campus_image_paths
    root = Rails.root.join("app/assets/images")
    Dir.glob(root.join("**", "*.{jpg,jpeg,png,webp}")).sort.filter_map do |absolute|
      relative = Pathname.new(absolute).relative_path_from(root).to_s
      next if File.basename(relative).start_with?(".")

      image_path(relative)
    end
  end

  def navigation_context
    controller_path.split("/").first
  end

  def navigation_items
    return admin_navigation_items if current_user.admin?
    return student_navigation_items if current_user.student?

    case navigation_context
    when "deans"
      dean_navigation_items
    else
      # Role-based (not namespace-based): /supervisor|/faculty and /dean|/faculty
      # share one list so the two items never swap order on click.
      return supervisor_navigation_items if supervisor_nav_user?
      return dean_navigation_items if dean_nav_user?

      faculty_navigation_items
    end
  end

  # Fixed order for every student surface (dashboard, profile, etc.).
  def student_navigation_items
    [ [ "Dashboard", student_root_path, "home" ],
      [ "Raise a req", new_student_achievement_request_path, "plus" ] ]
  end

  # Plain faculty (no supervisor/dean assignment).
  def faculty_navigation_items
    [ [ "Dashboard", faculty_root_path, "home" ],
      [ "Students", faculty_students_path, "users" ] ]
  end

  # Fixed order for every supervisor surface (queue, students, profile, etc.).
  def supervisor_navigation_items
    [ [ "Dashboard", supervisor_root_path, "home" ],
      [ "Students", faculty_students_path, "users" ],
      [ "Review queue", supervisor_queue_path, "check" ],
      [ "Review history", supervisor_review_histories_path, "history" ] ]
  end

  # Fixed order for every dean surface (queue, students, profile, etc.).
  def dean_navigation_items
    [ [ "Dashboard", dean_root_path, "home" ],
      [ "Students", faculty_students_path, "users" ],
      [ "Decision queue", dean_queue_path, "check" ],
      [ "Review history", dean_review_histories_path, "history" ] ]
  end

  def supervisor_nav_user?
    current_user.assigned_sub_divisions.exists?
  end

  def dean_nav_user?
    current_user.assigned_divisions.exists?
  end

  def nav_link_active?(path)
    return current_page?(path) if path.include?("?")

    if path == admin_root_path
      return request.path == admin_root_path
    end

    if path == admin_divisions_path
      return request.path.start_with?("/admin/divisions")
    end

    # Faculty dashboard: exact /faculty only.
    if path == faculty_root_path
      return request.path == faculty_root_path
    end

    # Students directory lives at /faculty/students.
    if path == faculty_students_path
      return request.path == faculty_students_path ||
             request.path.start_with?("#{faculty_students_path}/")
    end

    # Supervisor dashboard: exact root only.
    if path == supervisor_root_path
      return request.path == supervisor_root_path
    end

    # Review queue.
    if path == supervisor_queue_path
      return request.path == supervisor_queue_path
    end

    if path == supervisor_review_histories_path
      return request.path.start_with?(supervisor_review_histories_path)
    end

    # Dean dashboard: exact root only.
    if path == dean_root_path
      return request.path == dean_root_path
    end

    # Decision queue.
    if path == dean_queue_path
      return request.path == dean_queue_path
    end

    if path == dean_review_histories_path
      return request.path.start_with?(dean_review_histories_path)
    end

    # Dashboard: exact /student only — not /student/achievement_requests...
    if path == student_root_path
      return request.path == student_root_path
    end

    # Raise a req: new form and related achievement request paths.
    if path == new_student_achievement_request_path
      return request.path.start_with?("/student/achievement_requests")
    end

    # Settings hub and related configuration pages.
    if path == edit_admin_settings_path
      return request.path.start_with?("/admin/settings") ||
             request.path.start_with?("/admin/review_roles") ||
             request.path.start_with?("/admin/role_assignments") ||
             request.path.start_with?("/admin/hierarchies")
    end

    request.path == path || (path != root_path && request.path.start_with?("#{path}/"))
  end

  def admin_navigation_items
    [ [ "Dashboard", admin_root_path, "home" ],
      [ "Departments", admin_departments_path, "grid" ],
      [ "Divisions", admin_divisions_path, "layers" ],
      [ "Reason templates", admin_reason_templates_path, "list" ],
      [ "Users", admin_users_path, "users" ],
      [ "Import users", new_admin_user_import_path, "upload" ],
      [ "Settings", edit_admin_settings_path, "cog" ] ]
  end

  # Material Symbols Outlined icon names mapped from existing nav keys.
  def nav_icon(name, classes: "material-symbols-outlined")
    icons = {
      "home" => "dashboard",
      "plus" => "add",
      "users" => "group",
      "check" => "fact_check",
      "history" => "history",
      "grid" => "grid_view",
      "layers" => "account_tree",
      "list" => "list_alt",
      "upload" => "upload_file",
      "cog" => "settings"
    }

    glyph = icons[name.to_s] || "grid_view"
    tag.span glyph, class: classes, "aria-hidden": true
  end

  def material_icon(name, classes: "material-symbols-outlined")
    tag.span name.to_s, class: classes, "aria-hidden": true
  end

  # Ordered identity labels for profile / admin lists:
  # Admin → Dean → Supervisor → other ReviewRoles → Faculty (if no assignment) → Student.
  def identity_role_labels(user)
    labels = []
    labels << "Admin" if user.admin?

    if user.faculty?
      assignments = user.role_assignments.includes(:review_role).to_a
      role_names = assignments.filter_map { |a| a.review_role&.name }.uniq
      dean_name = ReviewRole::DEAN
      supervisor_name = ReviewRole::SUPERVISOR

      labels << dean_name if role_names.include?(dean_name)
      labels << supervisor_name if role_names.include?(supervisor_name)
      others = role_names.reject { |n| n == dean_name || n == supervisor_name }.sort
      labels.concat(others)
      labels << "Faculty" if role_names.empty?
    end

    labels << "Student" if user.student?
    labels
  end

  # Top-bar / chrome: single compact chip — first identity label.
  # Separate from status_badge (frozen for dashboard).
  def role_badge(user)
    label = chrome_role_label(user)
    tag.span label.upcase, class: chrome_role_badge_classes(label)
  end

  def role_badges(user)
    identity_role_labels(user).map do |label|
      tag.span label.upcase, class: chrome_role_badge_classes(label)
    end.join("\n").html_safe
  end

  def chrome_role_label(user)
    identity_role_labels(user).first || user.role.to_s.titleize
  end

  # Role assignments grouped by review role name for profile responsibility chips.
  # Returns [[role_name, [assignment, ...]], ...] in Dean → Supervisor → other order.
  def responsibility_groups(user)
    return [] unless user.faculty?

    assignments = user.role_assignments.includes(:review_role, :division, { sub_division: :division }).to_a
    by_name = assignments.group_by { |a| a.review_role&.name }
    by_name.delete(nil)
    return [] if by_name.empty?

    ordered_names = []
    ordered_names << ReviewRole::DEAN if by_name.key?(ReviewRole::DEAN)
    ordered_names << ReviewRole::SUPERVISOR if by_name.key?(ReviewRole::SUPERVISOR)
    ordered_names.concat((by_name.keys - ordered_names).sort)

    ordered_names.map { |name| [ name, by_name[name] ] }
  end

  def chrome_role_badge_classes(label)
    case label.to_s.downcase
    when "student" then "scats-badge scats-badge-info"
    when "dean" then "scats-badge scats-badge-dean"
    when "supervisor" then "scats-badge scats-badge-warning"
    when "admin" then "scats-badge scats-badge-admin"
    when "faculty" then "scats-badge scats-badge-neutral"
    else "scats-badge scats-badge-neutral"
    end
  end

  # Circular profile photo (or initial placeholder) used in admin tables,
  # profile, sidebar, and top bar.
  def user_photo_tag(user, size: 40)
    style = "width: #{size}px; height: #{size}px;"
    frame = "overflow-hidden rounded-full ring-1 ring-primary/15 align-middle"

    if user.photo.attached?
      # Use the original blob so pages render without a Vips/ImageMagick variant step.
      tag.span class: "inline-block #{frame}", style: style do
        image_tag user.photo, class: "block h-full w-full object-cover", alt: ""
      end
    else
      tag.span user_initials(user),
               class: "inline-flex items-center justify-center bg-primary/10 text-[11px] font-semibold text-primary #{frame}",
               style: style
    end
  end

  def user_initials(user)
    parts = user.name.to_s.split.reject(&:blank?)
    return "?" if parts.empty?

    if parts.length == 1
      parts.first.first(2).upcase
    else
      "#{parts.first[0]}#{parts.last[0]}".upcase
    end
  end

  # Small pulsing dot marking items that are waiting on the viewer's action
  # (reverted requests they haven't touched yet).
  def attention_dot(title = "Awaiting your action")
    tag.span "", class: "inline-block h-2 w-2 animate-pulse rounded-full bg-red-500 align-middle",
                 title: title, "aria-label": title
  end

  # A supervisor-reverted request returns to `submitted` on resubmit, so any
  # request still in that status is by definition unattended by the student.
  def student_attention_needed?
    return false unless current_user&.student? && current_user.student_profile

    current_user.student_profile.achievement_requests.reverted.exists?
  end

  # Requests awaiting this faculty member as the live current reviewer.
  def supervisor_attention_needed?
    return false unless current_user&.faculty?

    AchievementRequest.for_current_reviewer(current_user).exists?
  end
end
