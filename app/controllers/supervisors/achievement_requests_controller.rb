module Supervisors
  class AchievementRequestsController < BaseController
    before_action :set_request, only: [ :show, :approve, :revert, :reject, :edit, :update, :remove_proof ]
    # Approve also re-forwards dean_reverted requests. Revert applies to fresh
    # submissions, or to dean-reverted requests the student originally raised
    # (so the student can address the dean's feedback themselves). Reject only
    # applies to fresh submissions; editing only to dean-reverted ones.
    before_action :require_approvable_status, only: [ :approve ]
    before_action :require_revertable_status, only: [ :revert ]
    before_action :require_submitted_status, only: [ :reject ]
    before_action :require_dean_reverted_status, only: [ :edit, :update, :remove_proof ]

    def show
      authorize @achievement_request
      @achievement_request = AchievementRequest
        .includes(request_versions: [ :proofs_attachments, { req_histories: :actor } ],
                  category: { sub_division: :division },
                  student: {})
        .find(@achievement_request.id)
      @histories = @achievement_request.req_histories.includes(:actor).order(:created_at)
      @reason_templates = ReasonTemplate.order(:created_at)
    end

    def approve
      authorize @achievement_request, :review?
      action = @achievement_request.dean_reverted? ? "supervisor_reforward" : "supervisor_approve"
      @achievement_request.transition!(to: :supervisor_approved, actor: current_user,
                                       action: action)
      redirect_to supervisor_root_path, notice: "Request approved and forwarded to the dean."
    end

    def revert
      authorize @achievement_request, :review?
      decide_with_comment(to: :supervisor_reverted, action: "supervisor_revert",
                          notice: "Request reverted to the student.")
    end

    # Fix-ups on a dean-reverted request before re-forwarding it.
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
                  notice: "Draft version updated — re-forward when ready."
    rescue ActiveRecord::RecordInvalid => e
      @achievement_request.assign_attributes(update_params.except(:proofs, :remove_proof_ids))
      copy_record_errors(@achievement_request, e.record) unless e.record.is_a?(AchievementRequest)
      render :edit, status: :unprocessable_content
    end

    def reject
      authorize @achievement_request, :review?
      decide_with_comment(to: :rejected, action: "supervisor_reject",
                          notice: "Request rejected.")
    end

    # Path B — supervisor-initiated request.
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

      # A category outside the supervisor's sub-divisions is rejected up front;
      # blank student/category/title fall through to model validations below.
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
      redirect_to supervisor_root_path, notice: "Request raised on behalf of #{request.student.usn}."
    rescue ActiveRecord::RecordInvalid => e
      @achievement_request = form_request_from_invalid(e, attrs: request_params)
      render :new, status: :unprocessable_content
    end

    private

    def set_request
      @achievement_request = AchievementRequest.find(params[:id])
    end

    # When RequestVersion validations fail inside the create/revise transaction,
    # rebuild a form-friendly AchievementRequest that keeps submitted fields
    # (including student_id) and surfaces version errors such as blank proofs.
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

    def require_submitted_status
      return if @achievement_request.submitted?

      redirect_to supervisor_root_path, alert: "This request is no longer awaiting your review."
    end

    def require_approvable_status
      return if @achievement_request.submitted? || @achievement_request.dean_reverted?

      redirect_to supervisor_root_path, alert: "This request is no longer awaiting your review."
    end

    def require_revertable_status
      return if @achievement_request.submitted?
      return if @achievement_request.dean_reverted? && @achievement_request.student_initiated?

      redirect_to supervisor_root_path, alert: "This request cannot be reverted to the student."
    end

    # Editing is only for Path B requests the supervisor raised himself; a
    # student-initiated request goes back to the student for fixes instead.
    def require_dean_reverted_status
      return if @achievement_request.dean_reverted? && !@achievement_request.student_initiated?

      redirect_to supervisor_root_path, alert: "Only dean-reverted requests you raised can be edited."
    end

    def decide_with_comment(to:, action:, notice:)
      comment = params[:comment].to_s.strip
      if comment.blank?
        redirect_to supervisor_achievement_request_path(@achievement_request),
                    alert: "A message to the student is required."
        return
      end

      reason_template = ReasonTemplate.find_by(id: params[:reason_template_id])
      @achievement_request.transition!(to: to, actor: current_user, action: action,
                                       comment: comment, reason_template: reason_template)
      redirect_to supervisor_root_path, notice: notice
    end

    def supervised_categories
      Category.active.joins(:sub_division).where(sub_divisions: { supervisor_user_id: current_user.id })
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
