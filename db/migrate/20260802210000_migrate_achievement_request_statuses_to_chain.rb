class MigrateAchievementRequestStatusesToChain < ActiveRecord::Migration[8.1]
  STATUS_MAP = {
    "submitted" => "in_review",
    "supervisor_approved" => "in_review",
    "supervisor_reverted" => "reverted",
    "dean_reverted" => "in_review",
    "dean_approved" => "approved",
    "rejected" => "rejected",
    # Idempotent if re-run after a partial cutover:
    "in_review" => "in_review",
    "reverted" => "reverted",
    "approved" => "approved"
  }.freeze

  def up
    ReviewRole.ensure_system_roles!
    dean_role = ReviewRole.find_by!(name: ReviewRole::DEAN)
    supervisor_role = ReviewRole.find_by!(name: ReviewRole::SUPERVISOR)

    # Read raw DB strings — the model enum already only knows the new statuses,
    # so request.status would be nil for legacy values like "submitted".
    rows = select_all("SELECT id, status, category_id FROM achievement_requests")
    rows.each do |row|
      category = Category.find_by(id: row["category_id"])
      next unless category

      sub_division = category.sub_division
      division = sub_division.division
      supervisor_step = HierarchyStep.find_by(sub_division_id: sub_division.id, review_role_id: supervisor_role.id)
      dean_step = HierarchyStep.find_by(division_id: division.id, review_role_id: dean_role.id)

      old_status = row["status"]
      new_status = STATUS_MAP.fetch(old_status) { old_status }
      current_step_id = case old_status
      when "submitted", "dean_reverted", "in_review"
        # Keep existing step if already set later; for legacy, map by status.
        supervisor_step&.id
      when "supervisor_approved"
        dean_step&.id
      when "supervisor_reverted", "dean_approved", "rejected", "reverted", "approved"
        nil
      else
        nil
      end

      # For already-cutover in_review rows that somehow have a step, prefer leaving step alone
      if old_status == "in_review"
        existing = select_value("SELECT current_step_id FROM achievement_requests WHERE id = #{quote(row['id'])}")
        current_step_id = existing.presence || current_step_id
      end

      execute <<~SQL.squish
        UPDATE achievement_requests
        SET status = #{quote(new_status)},
            current_step_id = #{current_step_id.nil? ? 'NULL' : quote(current_step_id)}
        WHERE id = #{quote(row['id'])}
      SQL
    end

    change_column_default :achievement_requests, :status, from: "submitted", to: "in_review"
  end

  def down
    change_column_default :achievement_requests, :status, from: "in_review", to: "submitted"

    rows = select_all("SELECT id, status, current_step_id FROM achievement_requests")
    rows.each do |row|
      step = row["current_step_id"].present? ? HierarchyStep.find_by(id: row["current_step_id"]) : nil
      old_status = case row["status"]
      when "approved" then "dean_approved"
      when "rejected" then "rejected"
      when "reverted" then "supervisor_reverted"
      when "in_review"
        step&.division_id.present? ? "supervisor_approved" : "submitted"
      else
        row["status"]
      end

      execute <<~SQL.squish
        UPDATE achievement_requests
        SET status = #{quote(old_status)},
            current_step_id = NULL
        WHERE id = #{quote(row['id'])}
      SQL
    end
  end
end
