FactoryBot.define do
  factory :sub_division do
    division
    sequence(:name) { |n| "SubDivision #{n}" }
    association :supervisor, factory: [ :user, :faculty ]
  end
end
