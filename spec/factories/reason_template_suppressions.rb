FactoryBot.define do
  factory :reason_template_suppression do
    division
    reason_template { association :reason_template, :shared }
  end
end
