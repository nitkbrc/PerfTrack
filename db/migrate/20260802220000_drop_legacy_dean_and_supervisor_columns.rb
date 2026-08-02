class DropLegacyDeanAndSupervisorColumns < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :divisions, column: :dean_user_id if foreign_key_exists?(:divisions, column: :dean_user_id)
    remove_index :divisions, :dean_user_id if index_exists?(:divisions, :dean_user_id)
    remove_column :divisions, :dean_user_id, :bigint

    remove_foreign_key :sub_divisions, column: :supervisor_user_id if foreign_key_exists?(:sub_divisions, column: :supervisor_user_id)
    remove_index :sub_divisions, :supervisor_user_id if index_exists?(:sub_divisions, :supervisor_user_id)
    remove_column :sub_divisions, :supervisor_user_id, :bigint
  end

  def down
    add_reference :divisions, :dean_user, null: true, foreign_key: { to_table: :users }
    add_reference :sub_divisions, :supervisor_user, null: true, foreign_key: { to_table: :users }

    ReviewRole.ensure_system_roles!
    dean_role = ReviewRole.find_by!(name: ReviewRole::DEAN)
    supervisor_role = ReviewRole.find_by!(name: ReviewRole::SUPERVISOR)

    RoleAssignment.where(review_role: dean_role).find_each do |assignment|
      Division.where(id: assignment.division_id).update_all(dean_user_id: assignment.user_id)
    end
    RoleAssignment.where(review_role: supervisor_role).find_each do |assignment|
      SubDivision.where(id: assignment.sub_division_id).update_all(supervisor_user_id: assignment.user_id)
    end

    change_column_null :divisions, :dean_user_id, false
    change_column_null :sub_divisions, :supervisor_user_id, false
    add_index :divisions, :dean_user_id, unique: true
  end
end
