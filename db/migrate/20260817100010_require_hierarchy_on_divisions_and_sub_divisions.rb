class RequireHierarchyOnDivisionsAndSubDivisions < ActiveRecord::Migration[8.1]
  def up
    default_division_id = select_value(<<~SQL.squish)
      SELECT id FROM hierarchies WHERE scope = 'division' AND is_default = TRUE LIMIT 1
    SQL
    default_sub_id = select_value(<<~SQL.squish)
      SELECT id FROM hierarchies WHERE scope = 'sub_division' AND is_default = TRUE LIMIT 1
    SQL

    if default_division_id
      execute(<<~SQL.squish)
        UPDATE divisions SET hierarchy_id = #{default_division_id.to_i}
        WHERE hierarchy_id IS NULL
      SQL
    end
    if default_sub_id
      execute(<<~SQL.squish)
        UPDATE sub_divisions SET hierarchy_id = #{default_sub_id.to_i}
        WHERE hierarchy_id IS NULL
      SQL
    end

    change_column_null :divisions, :hierarchy_id, false
    change_column_null :sub_divisions, :hierarchy_id, false
  end

  def down
    change_column_null :divisions, :hierarchy_id, true
    change_column_null :sub_divisions, :hierarchy_id, true
  end
end
