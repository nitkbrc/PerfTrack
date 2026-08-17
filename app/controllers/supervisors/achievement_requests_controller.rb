module Supervisors
  class AchievementRequestsController < BaseController
    include DecisionReasons

    before_action :set_request, only: [ :show, :approve, :revert, :reject, :edit, :update, :remove_proof ]
    before_action :require_in_review, only: [ :approve, :revert, :reject ]
    before_action :require_raiseable_revision, only: [ :edit, :update, :remove_proof ]

    def show
      authorize @achievement_request
      @achievement_request = AchievementRequest
        .includes(request_versions: [ :proofs_attachments, { req_histories: :actor } ],
                  category: { sub_division: :division },
                  student: {}, current_review_role: {})
        .find(@achievement_request.id)
      @histories = @achievement_request.req_histories.includes(:actor).order(:created_at)
      load_decision_reason_templates!
    end

    def approve
      authorize @achievement_request, :review?
      @achievement_request.advance!(actor: current_user)
      redirect_to supervisor_queue_path, notice: "Request advanced to the next reviewer."
    end

    def revert
      authorize @achievement_request, :review?
      decide_revert(notice: "Request reverted.")
    end

    def edit
      authorize @achievement_request, :review?
    end

    def remove_proof
      authorize @achievement_request, :review?
      @achievement_request.remove_saved_proof!(actor: current_user, signed_id: params[:signed_id],
                                               draft_action: "supervisor_revise")
      render json: { ok: true }
    rescue ActiveRecord::RecordInvalid => e
      render json: { ok: false, error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def update
      authorize @achievement_request, :review?

      @achievement_request.revise!(actor: current_user, attrs: update_params)
      redirect_to supervisor_achievement_request_path(@achievement_request),
                  notice: "Draft version updated — advance when ready."
    rescue ActiveRecord::RecordInvalid => e
      @achievement_request.assign_attributes(update_params.except(:proofs, :remove_proof_ids))
      copy_record_errors(@achievement_request, e.record) unless e.record.is_a?(AchievementRequest)
      render :edit, status: :unprocessable_content
    end

    def reject
      authorize @achievement_request, :review?
      decide_reject(notice: "Request rejected.")
    end

    def new
      authorize AchievementRequest, :initiate?
      @achievement_request = AchievementRequest.new
      student_id = params.dig(:achievement_request, :student_id)
      if student_id.present? && ::Student.exists?(id: student_id)
        @achievement_request.student_id = student_id
      end
    end

    def create
      authorize AchievementRequest, :initiate?

      if request_params[:category_id].present? && !supervised_categories.exists?(id: request_params[:category_id])
        @achievement_request = AchievementRequest.new(request_params.except(:proofs))
        @achievement_request.errors.add(:category, "must be under one of your sub-divisions")
        return render :new, status: :unprocessable_content
      end

      request = AchievementRequest.supervisor_initiate!(
        student: ::Student.find_by(id: request_params[:student_id]),
        actor: current_user,
        attrs: request_params.except(:student_id)
      )
      redirect_to supervisor_queue_path, notice: "Request raised on behalf of #{request.student.usn}."
    rescue ActiveRecord::RecordInvalid => e
      @achievement_request = form_request_from_invalid(e, attrs: request_params)
      render :new, status: :unprocessable_content
    end

    private

    def set_request
      @achievement_request = AchievementRequest.find(params[:id])
    end

    def form_request_from_invalid(error, attrs:)
      return error.record if error.record.is_a?(AchievementRequest)

      request = AchievementRequest.new(attrs.except(:proofs))
      copy_record_errors(request, error.record)
      request
    end

    def copy_record_errors(target, source)
      source.errors.each do |err|
        target.errors.add(err.attribute, err.message)
      end
    end

    def require_in_review
      return if @achievement_request.in_review? && @achievement_request.current_reviewer&.id == current_user.id

      redirect_to supervisor_queue_path, alert: "This request is no longer awaiting your review."
    end

    def require_raiseable_revision
      return if @achievement_request.awaiting_raiseable_revision? &&
                @achievement_request.current_reviewer&.id == current_user.id

      redirect_to supervisor_queue_path, alert: "Only reverted requests you raised can be edited."
    end

    def decide_revert(notice:)
      if @achievement_request.raiser_role_removed?
        redirect_to supervisor_achievement_request_path(@achievement_request),
                    alert: AchievementRequest::RAISER_ROLE_REMOVED_MESSAGE
        return
      end

      resolved = resolve_decision_reason!(action: "revert")
      unless resolved[:ok]
        redirect_to supervisor_achievement_request_path(@achievement_request), alert: resolved[:alert]
        return
      end

      @achievement_request.revert!(actor: current_user, comment: resolved[:comment],
                                   reason_template: resolved[:reason_template])
      redirect_to supervisor_queue_path, notice: notice
    end

    def decide_reject(notice:)
      resolved = resolve_decision_reason!(action: "reject")
      unless resolved[:ok]
        redirect_to supervisor_achievement_request_path(@achievement_request), alert: resolved[:alert]
        return
      end

      @achievement_request.reject!(actor: current_user, comment: resolved[:comment],
                                   reason_template: resolved[:reason_template])
      redirect_to supervisor_queue_path, notice: notice
    end

    def supervised_categories
      Category.active.joins(:sub_division)
              .where(sub_divisions: { id: current_user.assigned_sub_divisions.select(:id) })
    end

    def request_params
      params.expect(achievement_request: [ :student_id, :category_id, :title, :description, { proofs: [] } ])
    end

    def update_params
      @update_params ||= params.expect(achievement_request: [ :title, :description,
                                                              { proofs: [], remove_proof_ids: [] } ])
    end
  end
end
