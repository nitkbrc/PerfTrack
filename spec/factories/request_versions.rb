FactoryBot.define do
  factory :request_version do
    association :achievement_request, with_version: false
    category { achievement_request.category }
    version_number { 1 }
    title { achievement_request.title }
    description { achievement_request.description }

    transient do
      with_proof { true }
    end

    after(:build) do |version, evaluator|
      if evaluator.with_proof
        version.proofs.attach(
          io: Rails.root.join("spec/fixtures/files/proof.png").open,
          filename: "proof.png",
          content_type: "image/png"
        )
      end
    end
  end
end
