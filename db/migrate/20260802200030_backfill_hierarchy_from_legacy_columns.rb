class BackfillHierarchyFromLegacyColumns < ActiveRecord::Migration[8.1]
  def up
    say_with_time "Ensuring system review roles" do
      ReviewRole.ensure_system_roles!
    end

    dean_role = ReviewRole.find_by!(name: ReviewRole::DEAN)
    supervisor_role = ReviewRole.find_by!(name: ReviewRole::SUPERVISOR)

    say_with_time "Backfilling division hierarchy steps and dean assignments" do
      Division.reset_column_information
      Division.find_each do |division|
        HierarchyStep.find_or_create_by!(review_role: dean_role, division_id: division.id) do |step|
          step.position = 1
          step.can_raise_on_behalf = false
        end

        next if division.dean_user_id.blank?

        RoleAssignment.find_or_create_by!(
          review_role: dean_role,
          division_id: division.id
        ) do |assignment|
          assignment.user_id = division.dean_user_id
        end
      end
    end

    say_with_time "Backfilling sub-division hierarchy steps and supervisor assignments" do
      SubDivision.reset_column_information
      SubDivision.find_each do |sub_division|
        HierarchyStep.find_or_create_by!(review_role: supervisor_role, sub_division_id: sub_division.id) do |step|
          step.position = 1
          step.can_raise_on_behalf = true
        end

        next if sub_division.supervisor_user_id.blank?

        RoleAssignment.find_or_create_by!(
          review_role: supervisor_role,
          sub_division_id: sub_division.id
        ) do |assignment|
          assignment.user_id = sub_division.supervisor_user_id
        end
      end
    end
  end

  def down
    RoleAssignment.delete_all
    HierarchyStep.delete_all
  end
end
