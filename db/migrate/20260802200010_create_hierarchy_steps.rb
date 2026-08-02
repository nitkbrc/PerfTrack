class CreateHierarchySteps < ActiveRecord::Migration[8.1]
  def change
    create_table :hierarchy_steps do |t|
      t.references :review_role, null: false, foreign_key: true
      t.references :division, null: true, foreign_key: true
      t.references :sub_division, null: true, foreign_key: true
      t.integer :position, null: false
      t.boolean :can_raise_on_behalf, null: false, default: false

      t.timestamps
    end

    add_index :hierarchy_steps, [ :division_id, :position ],
              unique: true, where: "division_id IS NOT NULL",
              name: "index_hierarchy_steps_on_division_and_position"
    add_index :hierarchy_steps, [ :sub_division_id, :position ],
              unique: true, where: "sub_division_id IS NOT NULL",
              name: "index_hierarchy_steps_on_sub_division_and_position"
    add_index :hierarchy_steps, [ :division_id, :review_role_id ],
              unique: true, where: "division_id IS NOT NULL",
              name: "index_hierarchy_steps_on_division_and_role"
    add_index :hierarchy_steps, [ :sub_division_id, :review_role_id ],
              unique: true, where: "sub_division_id IS NOT NULL",
              name: "index_hierarchy_steps_on_sub_division_and_role"
  end
end
