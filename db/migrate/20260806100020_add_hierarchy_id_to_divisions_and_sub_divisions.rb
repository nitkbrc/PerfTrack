class AddHierarchyIdToDivisionsAndSubDivisions < ActiveRecord::Migration[8.1]
  def change
    add_reference :divisions, :hierarchy, foreign_key: true
    add_reference :sub_divisions, :hierarchy, foreign_key: true
  end
end
