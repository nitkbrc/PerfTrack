class CreateRoleAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :role_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :review_role, null: false, foreign_key: true
      t.references :division, null: true, foreign_key: true
      t.references :sub_division, null: true, foreign_key: true

      t.timestamps
    end

    add_index :role_assignments, [ :review_role_id, :division_id ],
              unique: true, where: "division_id IS NOT NULL",
              name: "index_role_assignments_on_role_and_division"
    add_index :role_assignments, [ :review_role_id, :sub_division_id ],
              unique: true, where: "sub_division_id IS NOT NULL",
              name: "index_role_assignments_on_role_and_sub_division"
  end
end
