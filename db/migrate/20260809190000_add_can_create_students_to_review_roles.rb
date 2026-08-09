# frozen_string_literal: true

class AddCanCreateStudentsToReviewRoles < ActiveRecord::Migration[8.1]
  def change
    add_column :review_roles, :can_create_students, :boolean, null: false, default: false
  end
end
