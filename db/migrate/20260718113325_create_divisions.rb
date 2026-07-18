class CreateDivisions < ActiveRecord::Migration[8.1]
  def change
    create_table :divisions do |t|
      t.string :name
      t.string :div_type, null: false
      t.references :dean_user, null: false, foreign_key: { to_table: :users }, index: { unique: true }

      t.timestamps
    end
  end
end
