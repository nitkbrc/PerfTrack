class CreateHierarchyRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :hierarchy_roles do |t|
      t.references :hierarchy, null: false, foreign_key: true
      t.references :review_role, null: false, foreign_key: true
      t.integer :position, null: false
      t.boolean :can_raise_on_behalf, null: false, default: false

      t.timestamps
    end

    add_index :hierarchy_roles, [ :hierarchy_id, :review_role_id ], unique: true
    add_index :hierarchy_roles, [ :hierarchy_id, :position ], unique: true
  end
end
