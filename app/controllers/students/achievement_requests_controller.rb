module Students
  class AchievementRequestsController < BaseController
    before_action :load_division_tree, only: [ :new, :create ]

    def new
      @achievement_request = authorize AchievementRequest.new
    end

    def submitted
      authorize AchievementRequest, :index?
      @last_request = policy_scope(AchievementRequest).order(created_at: :desc).first
    end

    def create
      authorize AchievementRequest
      AchievementRequest.submit!(student: current_student, actor: current_user, attrs: request_params)
      redirect_to submitted_student_achievement_requests_path, notice: "Your request has been submitted."
    rescue ActiveRecord::RecordInvalid => e
      @achievement_request = if e.record.is_a?(AchievementRequest)
        e.record
      else
        request = AchievementRequest.new(request_params.except(:proofs))
        e.record.errors.each { |err| request.errors.add(err.attribute, err.message) }
        request
      end
      render :new, status: :unprocessable_content
    end

    def show
      @achievement_request = AchievementRequest
        .includes(request_versions: [ :proofs_attachments, { req_histories: :actor } ],
                  category: { sub_division: :division },
                  student: {})
        .find(params[:id])
      authorize @achievement_request
      @histories = @achievement_request.req_histories.includes(:actor).order(:created_at)
    end

    # Edit + resubmit of a supervisor-reverted request (PRD section 6:
    # Supervisor Reverted → Submitted). Category stays fixed; the student can
    # fix title/description and add more proofs.
    def edit
      @achievement_request = authorize AchievementRequest.find(params[:id]), :resubmit?
    end

    def remove_proof
      @achievement_request = authorize AchievementRequest.find(params[:id]), :resubmit?
      @achievement_request.remove_saved_proof!(actor: current_user, signed_id: params[:signed_id])
      render json: { ok: true }
    rescue ActiveRecord::RecordInvalid => e
      render json: { ok: false, error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def update
      @achievement_request = authorize AchievementRequest.find(params[:id]), :resubmit?

      @achievement_request.resubmit!(actor: current_user, attrs: update_params)
      redirect_to student_achievement_request_path(@achievement_request),
                  notice: "Your request has been resubmitted."
    rescue ActiveRecord::RecordInvalid => e
      @achievement_request.assign_attributes(update_params.except(:proofs, :remove_proof_ids))
      unless e.record.is_a?(AchievementRequest)
        e.record.errors.each { |err| @achievement_request.errors.add(err.attribute, err.message) }
      end
      render :edit, status: :unprocessable_content
    end

    private

    def request_params
      params.expect(achievement_request: [ :category_id, :title, :description, { proofs: [] } ])
    end

    def update_params
      @update_params ||= params.expect(achievement_request: [ :title, :description,
                                                              { proofs: [], remove_proof_ids: [] } ])
    end

    # Serialized once into the form so the cascading selects work without
    # network round-trips. Archived branches are filtered out — new requests
    # can only target the active tree.
    def load_division_tree
      @division_tree = Division.active.includes(sub_divisions: :categories).order(:name).map do |division|
        {
          id: division.id,
          name: division.name,
          divType: division.div_type,
          subDivisions: division.sub_divisions.reject(&:archived?).sort_by { |sd| sd.name.to_s }.map do |sub_division|
            {
              id: sub_division.id,
              name: sub_division.name,
              categories: sub_division.categories.reject(&:archived?).sort_by { |c| c.name.to_s }.map do |category|
                { id: category.id, name: category.name, points: category.points }
              end
            }
          end
        }
      end
    end
  end
end
