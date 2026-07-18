class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.references :achievement_request, null: false, foreign_key: true
      t.text :message, null: false
      t.boolean :read, null: false, default: false

      t.timestamps
    end

    # The bell badge counts unread rows per user on every page load.
    add_index :notifications, [ :recipient_id, :read ]
  end
end
