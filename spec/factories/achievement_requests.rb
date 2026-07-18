FactoryBot.define do
  factory :achievement_request do
    student
    category
    title { "Won a competition" }
    description { Faker::Lorem.sentence }

    transient do
      with_proof { true }
    end

    after(:build) do |request, evaluator|
      if evaluator.with_proof
        request.proofs.attach(
          io: Rails.root.join("spec/fixtures/files/proof.png").open,
          filename: "proof.png",
          content_type: "image/png"
        )
      end
    end
  end
end
