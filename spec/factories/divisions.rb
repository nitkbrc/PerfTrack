FactoryBot.define do
  factory :division do
    sequence(:name) { |n| "Division #{n}" }
    div_type { "positive" }
    association :dean, factory: [ :user, :faculty ]

    trait :negative do
      div_type { "negative" }
    end
  end
end
