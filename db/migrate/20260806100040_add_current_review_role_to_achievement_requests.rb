class AddCurrentReviewRoleToAchievementRequests < ActiveRecord::Migration[8.1]
  def change
    add_reference :achievement_requests, :current_review_role, foreign_key: { to_table: :review_roles }
  end
end
