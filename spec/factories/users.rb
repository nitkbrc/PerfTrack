FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:phone) { |n| format("%010d", 9_000_000_000 + n) }
    address { "123 Example Street, Demo City" }
    password { "password123" }
    role { "student" }

    after(:build) do |user|
      next if user.photo.attached?

      user.photo.attach(
        io: Rails.root.join("spec/fixtures/files/proof.png").open,
        filename: "photo.png",
        content_type: "image/png"
      )
    end

    trait :admin do
      role { "admin" }
    end

    trait :faculty do
      role { "faculty" }
    end
  end
end
