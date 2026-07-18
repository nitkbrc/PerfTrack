FactoryBot.define do
  factory :student do
    sequence(:usn) { |n| "1XX23CS#{format('%03d', n)}" }
    user
    department
    sem { 3 }
  end
end
