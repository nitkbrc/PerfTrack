FactoryBot.define do
  factory :sub_division do
    division
    sequence(:name) { |n| "SubDivision #{n}" }

    transient do
      supervisor { nil }
    end

    after(:create) do |sub_division, evaluator|
      ReviewRole.ensure_system_roles!
      Hierarchy.ensure_defaults!
      sub_division.update!(hierarchy: Hierarchy.default_for("sub_division")) if sub_division.hierarchy_id.blank?
      user = evaluator.supervisor || create(:user, :faculty)
      RoleAssignment.find_or_create_by!(review_role: ReviewRole.supervisor, sub_division: sub_division) do |a|
        a.user = user
      end
    end
  end
end
