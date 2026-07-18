module ApplicationHelper
  # Small pulsing dot marking items that are waiting on the viewer's action
  # (reverted requests they haven't touched yet).
  def attention_dot(title = "Awaiting your action")
    tag.span "", class: "inline-block h-2 w-2 animate-pulse rounded-full bg-red-500 align-middle",
                 title: title, "aria-label": title
  end

  # A supervisor-reverted request returns to `submitted` on resubmit, so any
  # request still in that status is by definition unattended by the student.
  def student_attention_needed?
    current_student.achievement_requests.supervisor_reverted.exists?
  end

  # Same logic for supervisors: dean_reverted requests leave that status once
  # the supervisor re-forwards (or reverts/edits), so their presence means
  # the supervisor hasn't acted yet.
  def supervisor_attention_needed?
    AchievementRequest.joins(category: :sub_division)
                      .where(sub_divisions: { supervisor_user_id: current_user.id },
                             status: :dean_reverted)
                      .exists?
  end
end
