class AddArchivedAtToDivisionTree < ActiveRecord::Migration[8.1]
  def change
    add_column :divisions, :archived_at, :datetime
    add_column :sub_divisions, :archived_at, :datetime
    add_column :categories, :archived_at, :datetime

    add_index :divisions, :archived_at
    add_index :sub_divisions, :archived_at
    add_index :categories, :archived_at
  end
end
