# frozen_string_literal: true

class DemoteAssociateDeanFromSystemRole < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE review_roles
      SET system_role = FALSE
      WHERE name = 'Associate Dean'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE review_roles
      SET system_role = TRUE,
          scope = 'division',
          raiseable_on_behalf_eligible = FALSE
      WHERE name = 'Associate Dean'
    SQL
  end
end
