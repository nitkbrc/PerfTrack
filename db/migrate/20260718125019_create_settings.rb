class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.integer :score_scale_k, null: false, default: 50

      t.timestamps
    end
  end
end
