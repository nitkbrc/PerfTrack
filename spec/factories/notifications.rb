FactoryBot.define do
  factory :notification do
    recipient factory: [ :user, :student ]
    achievement_request
    message { "Your request was approved." }
    read { false }
  end
end
