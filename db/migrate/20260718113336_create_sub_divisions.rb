class CreateSubDivisions < ActiveRecord::Migration[8.1]
  def change
    create_table :sub_divisions do |t|
      t.references :division, null: false, foreign_key: true
      t.string :name
      t.references :supervisor_user, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
