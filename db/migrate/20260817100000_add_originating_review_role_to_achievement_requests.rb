class AddOriginatingReviewRoleToAchievementRequests < ActiveRecord::Migration[8.1]
  def up
    add_reference :achievement_requests, :originating_review_role,
                  foreign_key: { to_table: :review_roles }, null: true

    say_with_time "backfill originating_review_role_id for Path B requests" do
      execute <<~SQL.squish
        UPDATE achievement_requests ar
        SET originating_review_role_id = sub.review_role_id
        FROM (
          SELECT DISTINCT ON (rh.achievement_request_id)
            rh.achievement_request_id,
            ra.review_role_id
          FROM req_histories rh
          INNER JOIN achievement_requests ar2 ON ar2.id = rh.achievement_request_id
          INNER JOIN categories c ON c.id = ar2.category_id
          INNER JOIN role_assignments ra
            ON ra.user_id = rh.actor_id
            AND ra.sub_division_id = c.sub_division_id
          INNER JOIN review_roles rr
            ON rr.id = ra.review_role_id
            AND rr.raiseable_on_behalf_eligible = TRUE
          WHERE rh.action = 'supervisor_initiate'
          ORDER BY rh.achievement_request_id, rh.created_at ASC, rh.id ASC
        ) sub
        WHERE ar.id = sub.achievement_request_id
          AND ar.originating_review_role_id IS NULL
      SQL
    end
  end

  def down
    remove_reference :achievement_requests, :originating_review_role, foreign_key: { to_table: :review_roles }
  end
end
