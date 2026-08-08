class CreateHierarchies < ActiveRecord::Migration[8.1]
  def change
    create_table :hierarchies do |t|
      t.string :name, null: false
      t.string :scope, null: false
      t.boolean :is_default, null: false, default: false

      t.timestamps
    end

    add_index :hierarchies, :name, unique: true
    add_index :hierarchies, [ :scope, :is_default ]
  end
end
