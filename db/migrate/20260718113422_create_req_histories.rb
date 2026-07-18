class CreateReqHistories < ActiveRecord::Migration[8.1]
  def change
    create_table :req_histories do |t|
      t.references :achievement_request, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.references :reason_template, null: true, foreign_key: true
      t.string :action
      t.string :from_status
      t.string :to_status
      t.text :comment

      t.timestamps
    end
  end
end
