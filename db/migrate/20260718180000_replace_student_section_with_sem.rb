class ReplaceStudentSectionWithSem < ActiveRecord::Migration[8.1]
  def change
    remove_column :students, :section, :string
    add_column :students, :sem, :integer
  end
end
