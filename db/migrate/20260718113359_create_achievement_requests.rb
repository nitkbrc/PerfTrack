class CreateAchievementRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :achievement_requests do |t|
      t.references :student, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.string :status, null: false, default: "submitted"
      t.integer :points_awarded

      t.timestamps
    end
  end
end
