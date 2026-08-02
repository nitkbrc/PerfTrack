FactoryBot.define do
  factory :sub_division do
    division
    sequence(:name) { |n| "SubDivision #{n}" }

    transient do
      supervisor { nil }
    end

    after(:create) do |sub_division, evaluator|
      ReviewRole.ensure_system_roles!
      user = evaluator.supervisor || create(:user, :faculty)
      RoleAssignment.find_or_create_by!(review_role: ReviewRole.supervisor, sub_division: sub_division) do |a|
        a.user = user
      end
    end
  end
end
