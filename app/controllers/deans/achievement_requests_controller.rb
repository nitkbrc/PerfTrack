module Deans
  class AchievementRequestsController < BaseController
    before_action :set_request
    before_action :require_supervisor_approved_status, only: [ :approve, :revert, :reject ]

    def show
      authorize @achievement_request
      @histories = @achievement_request.req_histories.includes(:actor).order(:created_at)
      @reason_templates = ReasonTemplate.order(:created_at)
    end

    def approve
      authorize @achievement_request, :dean_decide?
      @achievement_request.dean_approve!(actor: current_user)
      redirect_to dean_root_path,
                  notice: "Request approved — #{@achievement_request.points_awarded} points awarded."
    end

    def revert
      authorize @achievement_request, :dean_decide?
      decide_with_comment(to: :dean_reverted, action: "dean_revert",
                          notice: "Request sent back to the supervisor for clarification.")
    end

    def reject
      authorize @achievement_request, :dean_decide?
      decide_with_comment(to: :rejected, action: "dean_reject",
                          notice: "Request rejected.")
    end

    private

    def set_request
      @achievement_request = AchievementRequest.find(params[:id])
    end

    def require_supervisor_approved_status
      return if @achievement_request.supervisor_approved?

      redirect_to dean_root_path, alert: "This request is no longer awaiting your decision."
    end

    def decide_with_comment(to:, action:, notice:)
      comment = params[:comment].to_s.strip
      if comment.blank?
        redirect_to dean_achievement_request_path(@achievement_request),
                    alert: "A message is required."
        return
      end

      reason_template = ReasonTemplate.find_by(id: params[:reason_template_id])
      @achievement_request.transition!(to: to, actor: current_user, action: action,
                                       comment: comment, reason_template: reason_template)
      redirect_to dean_root_path, notice: notice
    end
  end
end
