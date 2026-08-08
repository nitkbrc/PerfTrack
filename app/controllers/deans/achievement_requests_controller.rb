module Deans
  class AchievementRequestsController < BaseController
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
      @reason_templates = ReasonTemplate.order(:created_at)
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
      comment = params[:comment].to_s.strip
      if comment.blank?
        redirect_to dean_achievement_request_path(@achievement_request),
                    alert: "A message is required."
        return
      end

      @achievement_request.revert!(actor: current_user, comment: comment)
      redirect_to dean_queue_path, notice: notice
    end

    def decide_reject(notice:)
      comment = params[:comment].to_s.strip
      if comment.blank?
        redirect_to dean_achievement_request_path(@achievement_request),
                    alert: "A message is required."
        return
      end

      reason_template = ReasonTemplate.find_by(id: params[:reason_template_id])
      @achievement_request.reject!(actor: current_user, comment: comment,
                                   reason_template: reason_template)
      redirect_to dean_queue_path, notice: notice
    end
  end
end
