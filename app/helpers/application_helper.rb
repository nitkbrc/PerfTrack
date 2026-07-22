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
      [ "Review queue", supervisor_root_path, "check" ] ]
  end

  # Fixed order for every dean surface (queue, students, profile, etc.).
  def dean_navigation_items
    [ [ "Students", faculty_students_path, "users" ],
      [ "Decision queue", dean_root_path, "check" ] ]
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

    # Review queue: only the supervisor namespace (exact root or nested).
    if path == supervisor_root_path
      return request.path == supervisor_root_path ||
             request.path.start_with?("#{supervisor_root_path}/")
    end

    # Decision queue: only the dean namespace (exact root or nested).
    if path == dean_root_path
      return request.path == dean_root_path ||
             request.path.start_with?("#{dean_root_path}/")
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

  # Inline SVG icons for collapsed sidebar / bottom nav (Heroicons-style outlines).
  def nav_icon(name, classes: "h-5 w-5")
    paths = {
      "grid" => '<path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 0 1 6 3.75h2.25A2.25 2.25 0 0 1 10.5 6v2.25a2.25 2.25 0 0 1-2.25 2.25H6a2.25 2.25 0 0 1-2.25-2.25V6ZM13.5 6a2.25 2.25 0 0 1 2.25-2.25H18A2.25 2.25 0 0 1 20.25 6v2.25A2.25 2.25 0 0 1 18 10.5h-2.25a2.25 2.25 0 0 1-2.25-2.25V6ZM3.75 15.75A2.25 2.25 0 0 1 6 13.5h2.25a2.25 2.25 0 0 1 2.25 2.25V18A2.25 2.25 0 0 1 8.25 20.25H6A2.25 2.25 0 0 1 3.75 18v-2.25ZM13.5 15.75a2.25 2.25 0 0 1 2.25-2.25H18a2.25 2.25 0 0 1 2.25 2.25V18A2.25 2.25 0 0 1 18 20.25h-2.25A2.25 2.25 0 0 1 13.5 18v-2.25Z"/>',
      "layers" => '<path stroke-linecap="round" stroke-linejoin="round" d="M6.429 9.75 2.25 12l4.179 2.25m0-4.5 5.571 3 5.571-3m-11.142 0L2.25 7.5 12 2.25l9.75 5.25-4.179 2.25m0 0L21.75 12l-4.179 2.25m0 0 4.179 2.25L12 21.75 2.25 16.5l4.179-2.25m11.142 0-5.571 3-5.571-3"/>',
      "list" => '<path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"/>',
      "users" => '<path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 0 0 2.625.372 9.337 9.337 0 0 0 4.121-.952 4.125 4.125 0 0 0-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 0 1 8.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0 1 11.964-3.07M12 6.375a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0Zm8.25 2.25a2.625 2.625 0 1 1-5.25 0 2.625 2.625 0 0 1 5.25 0Z"/>',
      "upload" => '<path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5m-13.5-9L12 3m0 0 4.5 4.5M12 3v13.5"/>',
      "cog" => '<path stroke-linecap="round" stroke-linejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.325.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 0 1 1.37.49l1.296 2.247a1.125 1.125 0 0 1-.26 1.431l-1.003.827c-.293.241-.438.613-.43.992a7.723 7.723 0 0 1 0 .255c-.008.378.137.75.43.991l1.004.827c.424.35.534.955.26 1.43l-1.298 2.247a1.125 1.125 0 0 1-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.47 6.47 0 0 1-.22.128c-.331.183-.581.495-.644.869l-.213 1.281c-.09.543-.56.94-1.11.94h-2.594c-.55 0-1.019-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 0 1-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 0 1-1.369-.49l-1.297-2.247a1.125 1.125 0 0 1 .26-1.431l1.004-.827c.292-.24.437-.613.43-.991a6.932 6.932 0 0 1 0-.255c.007-.38-.138-.751-.43-.992l-1.004-.827a1.125 1.125 0 0 1-.26-1.43l1.297-2.247a1.125 1.125 0 0 1 1.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.28Z"/><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z"/>',
      "check" => '<path stroke-linecap="round" stroke-linejoin="round" d="m4.5 12.75 6 6 9-13.5"/>',
      "plus" => '<path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>',
      "home" => '<path stroke-linecap="round" stroke-linejoin="round" d="m2.25 12 8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25"/>'
    }

    inner = paths[name.to_s] || paths["grid"]
    tag.svg xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24",
            "stroke-width": "1.5", stroke: "currentColor", class: classes, "aria-hidden": true do
      inner.html_safe
    end
  end

  # Circular profile photo (or initial placeholder) used in admin tables,
  # profile, sidebar, and bottom nav.
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
