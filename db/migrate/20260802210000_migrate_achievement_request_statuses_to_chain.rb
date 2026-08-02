class MigrateAchievementRequestStatusesToChain < ActiveRecord::Migration[8.1]
  STATUS_MAP = {
    "submitted" => "in_review",
    "supervisor_approved" => "in_review",
    "supervisor_reverted" => "reverted",
    "dean_reverted" => "in_review",
    "dean_approved" => "approved",
    "rejected" => "rejected"
  }.freeze

  def up
    ReviewRole.ensure_system_roles!
    dean_role = ReviewRole.find_by!(name: ReviewRole::DEAN)
    supervisor_role = ReviewRole.find_by!(name: ReviewRole::SUPERVISOR)

    AchievementRequest.reset_column_information
    AchievementRequest.find_each do |request|
      sub_division = request.category.sub_division
      division = sub_division.division
      supervisor_step = HierarchyStep.find_by(sub_division_id: sub_division.id, review_role_id: supervisor_role.id)
      dean_step = HierarchyStep.find_by(division_id: division.id, review_role_id: dean_role.id)

      new_status = STATUS_MAP.fetch(request.status)
      current_step_id = case request.status
      when "submitted", "dean_reverted"
        supervisor_step&.id
      when "supervisor_approved"
        dean_step&.id
      when "supervisor_reverted", "dean_approved", "rejected"
        nil
      end

      request.update_columns(status: new_status, current_step_id: current_step_id)
    end

    change_column_default :achievement_requests, :status, from: "submitted", to: "in_review"
  end

  def down
    change_column_default :achievement_requests, :status, from: "in_review", to: "submitted"

    AchievementRequest.reset_column_information
    AchievementRequest.find_each do |request|
      old_status = case request.status
      when "approved" then "dean_approved"
      when "rejected" then "rejected"
      when "reverted" then "supervisor_reverted"
      when "in_review"
        if request.current_step&.division_id.present?
          "supervisor_approved"
        else
          "submitted"
        end
      else
        request.status
      end
      request.update_columns(status: old_status, current_step_id: nil)
    end
  end
end
