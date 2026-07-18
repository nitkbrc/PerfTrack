class CreateStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :students do |t|
      t.string :usn, null: false
      t.references :user, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: true
      t.string :section

      t.timestamps
    end

    add_index :students, :usn, unique: true
  end
end
