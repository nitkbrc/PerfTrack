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
      at_step { nil } # :supervisor, :dean, or a HierarchyStep
    end

    trait :reverted do
      status { "reverted" }
      current_step { nil }
    end

    trait :approved do
      status { "approved" }
      current_step { nil }
      points_awarded { 10 }
    end

    trait :rejected do
      status { "rejected" }
      current_step { nil }
    end

    after(:create) do |request, evaluator|
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

      step = case evaluator.at_step
      when :supervisor
        request.category.sub_division.hierarchy_steps.ordered.first
      when :dean
        request.category.sub_division.division.hierarchy_steps.ordered.first
      when HierarchyStep
        evaluator.at_step
      when nil
        if request.in_review? && request.current_step_id.blank?
          request.category.sub_division.hierarchy_steps.ordered.first
        end
      end
      request.update_columns(current_step_id: step.id) if step
    end
  end
end
