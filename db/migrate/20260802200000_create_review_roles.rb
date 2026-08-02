class CreateReviewRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :review_roles do |t|
      t.string :name, null: false
      t.string :scope, null: false
      t.boolean :raiseable_on_behalf_eligible, null: false, default: false
      t.boolean :system_role, null: false, default: false

      t.timestamps
    end

    add_index :review_roles, :name, unique: true
  end
end
