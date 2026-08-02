class CreatePermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :permissions do |t|
      t.string :role, null: false
      t.string :action, null: false
      t.boolean :enabled, null: false, default: false

      t.timestamps
    end

    add_index :permissions, [ :role, :action ], unique: true
  end
end
