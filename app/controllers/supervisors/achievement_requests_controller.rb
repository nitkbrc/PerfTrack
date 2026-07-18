module Supervisors
  class AchievementRequestsController < BaseController
    before_action :set_request, only: [ :show, :approve, :revert, :reject ]
    before_action :require_submitted_status, only: [ :approve, :revert, :reject ]

    def show
      authorize @achievement_request
      @histories = @achievement_request.req_histories.includes(:actor).order(:created_at)
      @reason_templates = ReasonTemplate.order(:created_at)
    end

    def approve
      authorize @achievement_request, :review?
      @achievement_request.transition!(to: :supervisor_approved, actor: current_user,
                                       action: "supervisor_approve")
      redirect_to supervisor_root_path, notice: "Request approved and forwarded to the dean."
    end

    def revert
      authorize @achievement_request, :review?
      decide_with_comment(to: :supervisor_reverted, action: "supervisor_revert",
                          notice: "Request reverted to the student.")
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
    end

    def create
      authorize AchievementRequest, :initiate?

      # A category outside the supervisor's sub-divisions is rejected up front;
      # blank student/category/title fall through to model validations below.
      if request_params[:category_id].present? && !supervised_categories.exists?(id: request_params[:category_id])
        @achievement_request = AchievementRequest.new(request_params.except(:student_id))
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
      Category.joins(:sub_division).where(sub_divisions: { supervisor_user_id: current_user.id })
    end

    def request_params
      params.expect(achievement_request: [ :student_id, :category_id, :title, :description, { proofs: [] } ])
    end
  end
end
