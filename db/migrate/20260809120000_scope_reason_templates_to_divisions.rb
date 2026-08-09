# frozen_string_literal: true

class ScopeReasonTemplatesToDivisions < ActiveRecord::Migration[8.1]
  class ReasonTemplate < ApplicationRecord
    self.table_name = "reason_templates"
  end

  class Division < ApplicationRecord
    self.table_name = "divisions"
  end

  class ReqHistory < ApplicationRecord
    self.table_name = "req_histories"
  end

  def up
    add_reference :reason_templates, :division, foreign_key: true, null: true
    add_column :reason_templates, :action, :string
    add_column :reason_templates, :position, :integer, null: false, default: 0

    say_with_time "backfill reason templates per division/action" do
      globals = ReasonTemplate.where(division_id: nil).order(:id).to_a
      divisions = Division.order(:id).to_a

      if globals.any? && divisions.any?
        divisions.each do |division|
          %w[revert reject].each do |action|
            globals.each_with_index do |template, index|
              ReasonTemplate.create!(
                division_id: division.id,
                action: action,
                message_text: template.message_text,
                position: index,
                created_at: template.created_at,
                updated_at: Time.current
              )
            end
          end
        end
      end

      # Histories may still point at global rows; clear before delete.
      ReqHistory.where(reason_template_id: globals.map(&:id)).update_all(reason_template_id: nil) if globals.any?
      ReasonTemplate.where(id: globals.map(&:id)).delete_all if globals.any?
    end

    # Orphans with no division left (no divisions existed) get dropped.
    ReasonTemplate.where(division_id: nil).delete_all

    change_column_null :reason_templates, :division_id, false
    change_column_null :reason_templates, :action, false

    add_index :reason_templates, [ :division_id, :action, :position ],
              name: "index_reason_templates_on_division_action_position"
  end

  def down
    remove_index :reason_templates, name: "index_reason_templates_on_division_action_position"
    remove_column :reason_templates, :position
    remove_column :reason_templates, :action
    remove_reference :reason_templates, :division, foreign_key: true
  end
end
