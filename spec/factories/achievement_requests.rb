FactoryBot.define do
  factory :achievement_request do
    student
    category
    title { "Won a competition" }
    description { Faker::Lorem.sentence }

    transient do
      with_proof { true }
      with_version { true }
    end

    after(:create) do |request, evaluator|
      next unless evaluator.with_version
      next if request.request_versions.exists?

      version = request.request_versions.build(
        version_number: 1,
        title: request.title,
        description: request.description,
        category: request.category
      )
      if evaluator.with_proof
        version.proofs.attach(
          io: Rails.root.join("spec/fixtures/files/proof.png").open,
          filename: "proof.png",
          content_type: "image/png"
        )
      end
      version.save!(validate: evaluator.with_proof)
    end
  end
end
