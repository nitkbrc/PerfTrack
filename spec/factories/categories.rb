FactoryBot.define do
  factory :category do
    sub_division
    sequence(:name) { |n| "Category #{n}" }
    points { 20 }
  end
end
