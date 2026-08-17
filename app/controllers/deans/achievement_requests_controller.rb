module Deans
  class AchievementRequestsController < BaseController
    include DecisionReasons

    before_action :set_request
    before_action :require_in_review, only: [ :approve, :revert, :reject ]

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
      authorize @achievement_request, :dean_decide?
      @achievement_request.advance!(actor: current_user)
      notice = if @achievement_request.approved?
        "Request approved — #{@achievement_request.points_awarded} points awarded."
      else
        "Request advanced to the next reviewer."
      end
      redirect_to dean_queue_path, notice: notice
    end

    def revert
      authorize @achievement_request, :dean_decide?
      decide_revert(notice: "Request sent back to the previous reviewer.")
    end

    def reject
      authorize @achievement_request, :dean_decide?
      decide_reject(notice: "Request rejected.")
    end

    private

    def set_request
      @achievement_request = AchievementRequest.find(params[:id])
    end

    def require_in_review
      return if @achievement_request.in_review? && @achievement_request.current_reviewer&.id == current_user.id

      redirect_to dean_queue_path, alert: "This request is no longer awaiting your decision."
    end

    def decide_revert(notice:)
      if @achievement_request.raiser_role_removed?
        redirect_to dean_achievement_request_path(@achievement_request),
                    alert: AchievementRequest::RAISER_ROLE_REMOVED_MESSAGE
        return
      end

      resolved = resolve_decision_reason!(action: "revert")
      unless resolved[:ok]
        redirect_to dean_achievement_request_path(@achievement_request), alert: resolved[:alert]
        return
      end

      @achievement_request.revert!(actor: current_user, comment: resolved[:comment],
                                   reason_template: resolved[:reason_template])
      redirect_to dean_queue_path, notice: notice
    end

    def decide_reject(notice:)
      resolved = resolve_decision_reason!(action: "reject")
      unless resolved[:ok]
        redirect_to dean_achievement_request_path(@achievement_request), alert: resolved[:alert]
        return
      end

      @achievement_request.reject!(actor: current_user, comment: resolved[:comment],
                                   reason_template: resolved[:reason_template])
      redirect_to dean_queue_path, notice: notice
    end
  end
end
