FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    role { "student" }

    trait :admin do
      role { "admin" }
    end

    trait :faculty do
      role { "faculty" }
    end
  end
end
