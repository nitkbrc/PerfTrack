module Supervisors
  class AchievementRequestsController < BaseController
    before_action :set_request, only: [ :show, :approve, :revert, :reject, :edit, :update ]
    # Approve also re-forwards dean_reverted requests. Revert applies to fresh
    # submissions, or to dean-reverted requests the student originally raised
    # (so the student can address the dean's feedback themselves). Reject only
    # applies to fresh submissions; editing only to dean-reverted ones.
    before_action :require_approvable_status, only: [ :approve ]
    before_action :require_revertable_status, only: [ :revert ]
    before_action :require_submitted_status, only: [ :reject ]
    before_action :require_dean_reverted_status, only: [ :edit, :update ]

    def show
      authorize @achievement_request
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

    def update
      authorize @achievement_request, :review?

      ApplicationRecord.transaction do
        @achievement_request.proofs.attach(update_params[:proofs]) if update_params[:proofs].present?
        @achievement_request.update!(update_params.except(:proofs))
      end
      redirect_to supervisor_achievement_request_path(@achievement_request),
                  notice: "Changes saved — re-forward when ready."
    rescue ActiveRecord::RecordInvalid
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
        @achievement_request = AchievementRequest.new(request_params)
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
      @achievement_request = e.record.is_a?(AchievementRequest) ? e.record : AchievementRequest.new
      render :new, status: :unprocessable_content
    end

    private

    def set_request
      @achievement_request = AchievementRequest.find(params[:id])
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
      @update_params ||= params.expect(achievement_request: [ :title, :description, { proofs: [] } ])
    end
  end
end
