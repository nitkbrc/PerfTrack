class CreateSubDivisionRaiseableOverrides < ActiveRecord::Migration[8.1]
  def change
    create_table :sub_division_raiseable_overrides do |t|
      t.references :sub_division, null: false, foreign_key: true
      t.references :review_role, null: false, foreign_key: true
      t.boolean :can_raise_on_behalf, null: false, default: false

      t.timestamps
    end

    add_index :sub_division_raiseable_overrides,
              [ :sub_division_id, :review_role_id ],
              unique: true,
              name: "index_sub_div_raiseable_overrides_on_sub_and_role"
  end
end
