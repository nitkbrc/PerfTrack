FactoryBot.define do
  factory :achievement_request do
    student
    category
    title { "Won a competition" }
    description { Faker::Lorem.sentence }
    status { "in_review" }

    transient do
      with_proof { true }
      with_version { true }
      at_step { nil } # :supervisor, :dean, or a ReviewRole
    end

    trait :reverted do
      status { "reverted" }
      current_review_role { nil }
    end

    trait :approved do
      status { "approved" }
      current_review_role { nil }
      points_awarded { 10 }
    end

    trait :rejected do
      status { "rejected" }
      current_review_role { nil }
    end

    after(:create) do |request, evaluator|
      Hierarchy.ensure_defaults!
      if evaluator.with_version && !request.request_versions.exists?
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

      role = case evaluator.at_step
      when :supervisor
        ReviewRole.supervisor
      when :dean
        ReviewRole.dean
      when ReviewRole
        evaluator.at_step
      when nil
        if request.in_review? && request.current_review_role_id.blank?
          ReviewRole.supervisor
        end
      end
      request.update_columns(current_review_role_id: role.id) if role
    end
  end
end
