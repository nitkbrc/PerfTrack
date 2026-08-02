FactoryBot.define do
  factory :division do
    sequence(:name) { |n| "Division #{n}" }
    div_type { "positive" }

    transient do
      dean { nil }
    end

    trait :negative do
      div_type { "negative" }
    end

    after(:create) do |division, evaluator|
      ReviewRole.ensure_system_roles!
      user = evaluator.dean || create(:user, :faculty)
      RoleAssignment.find_or_create_by!(review_role: ReviewRole.dean, division: division) do |a|
        a.user = user
      end
    end
  end
end
