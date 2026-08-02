class AddCurrentStepToAchievementRequests < ActiveRecord::Migration[8.1]
  def change
    add_reference :achievement_requests, :current_step, null: true,
                  foreign_key: { to_table: :hierarchy_steps }
  end
end
