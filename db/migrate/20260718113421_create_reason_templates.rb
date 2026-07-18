class CreateReasonTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :reason_templates do |t|
      t.text :message_text

      t.timestamps
    end
  end
end
