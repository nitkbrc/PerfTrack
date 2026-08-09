# frozen_string_literal: true

class IntroduceSharedReasonTemplateDefaults < ActiveRecord::Migration[8.1]
  class ReasonTemplate < ApplicationRecord
    self.table_name = "reason_templates"
  end

  class ReqHistory < ApplicationRecord
    self.table_name = "req_histories"
  end

  def up
    change_column_null :reason_templates, :division_id, true

    create_table :reason_template_suppressions do |t|
      t.references :division, null: false, foreign_key: true
      t.references :reason_template, null: false, foreign_key: true
      t.timestamps
    end
    add_index :reason_template_suppressions,
              [ :division_id, :reason_template_id ],
              unique: true,
              name: "index_reason_template_suppressions_uniqueness"

    say_with_time "collapse duplicate division templates into shared defaults" do
      %w[revert reject].each do |action|
        # Texts copied to multiple divisions become one shared default.
        duplicated_texts = ReasonTemplate
          .where(action: action)
          .where.not(division_id: nil)
          .group(:message_text)
          .having("COUNT(*) > 1")
          .pluck(:message_text)

        duplicated_texts.each do |text|
          existing_shared = ReasonTemplate.find_by(division_id: nil, action: action, message_text: text)
          shared = existing_shared || ReasonTemplate.create!(
            division_id: nil,
            action: action,
            message_text: text,
            position: next_shared_position(action)
          )

          old_ids = ReasonTemplate
            .where(action: action, message_text: text)
            .where.not(id: shared.id)
            .pluck(:id)

          ReqHistory.where(reason_template_id: old_ids).update_all(reason_template_id: shared.id) if old_ids.any?
          ReasonTemplate.where(id: old_ids).delete_all if old_ids.any?
        end
      end
    end
  end

  def down
    drop_table :reason_template_suppressions

    # Shared defaults cannot be required to have a division; leave nullable.
    # Re-expanding to every division is intentionally not reversed.
  end

  private

  def next_shared_position(action)
    max = ReasonTemplate.where(division_id: nil, action: action).maximum(:position)
    max.nil? ? 0 : max + 1
  end
end
