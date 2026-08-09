FactoryBot.define do
  factory :reason_template do
    division { nil }
    action { "revert" }
    message_text { "Please attach clearer proof." }

    trait :shared do
      division { nil }
    end

    trait :division_extra do
      division
    end

    trait :reject do
      action { "reject" }
      message_text { "Insufficient evidence to verify this claim." }
    end
  end
end
