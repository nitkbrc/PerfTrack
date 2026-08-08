class DropHierarchyStepsAndCurrentStep < ActiveRecord::Migration[8.1]
  def up
    if foreign_key_exists?(:achievement_requests, :hierarchy_steps, column: :current_step_id)
      remove_foreign_key :achievement_requests, column: :current_step_id
    end
    if index_exists?(:achievement_requests, :current_step_id)
      remove_index :achievement_requests, :current_step_id
    end
    if column_exists?(:achievement_requests, :current_step_id)
      remove_column :achievement_requests, :current_step_id
    end

    drop_table :hierarchy_steps, if_exists: true
  end

  def down
    create_table :hierarchy_steps do |t|
      t.references :review_role, null: false, foreign_key: true
      t.references :division, foreign_key: true
      t.references :sub_division, foreign_key: true
      t.integer :position, null: false
      t.boolean :can_raise_on_behalf, null: false, default: false
      t.timestamps
    end

    add_reference :achievement_requests, :current_step, foreign_key: { to_table: :hierarchy_steps }
  end
end
