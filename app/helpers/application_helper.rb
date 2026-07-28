module ApplicationHelper
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

      [ [ "Students", faculty_students_path, "users" ] ]
    end
  end

  # Fixed order for every student surface (dashboard, profile, etc.).
  def student_navigation_items
    [ [ "Dashboard", student_root_path, "home" ],
      [ "Raise a req", new_student_achievement_request_path, "plus" ] ]
  end

  # Fixed order for every supervisor surface (queue, students, profile, etc.).
  def supervisor_navigation_items
    [ [ "Students", faculty_students_path, "users" ],
      [ "Review queue", supervisor_root_path, "check" ],
      [ "Review history", supervisor_review_histories_path, "history" ] ]
  end

  # Fixed order for every dean surface (queue, students, profile, etc.).
  def dean_navigation_items
    [ [ "Students", faculty_students_path, "users" ],
      [ "Decision queue", dean_root_path, "check" ],
      [ "Review history", dean_review_histories_path, "history" ] ]
  end

  def supervisor_nav_user?
    current_user.supervised_sub_divisions.exists?
  end

  def dean_nav_user?
    current_user.deaned_divisions.exists?
  end

  def nav_link_active?(path)
    return current_page?(path) if path.include?("?")

    if path == admin_divisions_path
      return request.path == admin_root_path || request.path.start_with?("/admin/divisions")
    end

    # Students directory lives at /faculty and /faculty/students — not /supervisor or /dean.
    if path == faculty_students_path || path == faculty_root_path
      return request.path == faculty_root_path ||
             request.path == faculty_students_path ||
             request.path.start_with?("#{faculty_students_path}/")
    end

    # Review queue: only the supervisor root (not nested show/history pages).
    if path == supervisor_root_path
      return request.path == supervisor_root_path
    end

    if path == supervisor_review_histories_path
      return request.path.start_with?(supervisor_review_histories_path)
    end

    # Decision queue: only the dean root (not nested show/history pages).
    if path == dean_root_path
      return request.path == dean_root_path
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

    request.path == path || (path != root_path && request.path.start_with?("#{path}/"))
  end

  def admin_navigation_items
    [ [ "Departments", admin_departments_path, "grid" ], [ "Divisions", admin_divisions_path, "layers" ],
      [ "Reason templates", admin_reason_templates_path, "list" ], [ "Users", admin_users_path, "users" ],
      [ "Import users", new_admin_user_import_path, "upload" ], [ "Settings", edit_admin_settings_path, "cog" ] ]
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

  # Circular profile photo (or initial placeholder) used in admin tables,
  # profile, sidebar, and top bar.
  def user_photo_tag(user, size: 40)
    style = "width: #{size}px; height: #{size}px;"
    frame = "overflow-hidden rounded-full ring-1 ring-slate-200 align-middle"

    if user.photo.attached?
      # Use the original blob so pages render without a Vips/ImageMagick variant step.
      tag.span class: "inline-block #{frame}", style: style do
        image_tag user.photo, class: "block h-full w-full object-cover", alt: ""
      end
    else
      tag.span user.name.to_s.first&.upcase || "?",
               class: "inline-flex items-center justify-center bg-slate-200 text-xs font-semibold text-slate-600 #{frame}",
               style: style
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

    current_user.student_profile.achievement_requests.supervisor_reverted.exists?
  end

  # Same logic for supervisors: dean_reverted requests leave that status once
  # the supervisor re-forwards (or reverts/edits), so their presence means
  # the supervisor hasn't acted yet.
  def supervisor_attention_needed?
    return false unless current_user&.faculty?

    AchievementRequest.joins(category: :sub_division)
                      .where(sub_divisions: { supervisor_user_id: current_user.id },
                             status: :dean_reverted)
                      .exists?
  end
end
