module Supervisors
  class QueueController < BaseController
    def index
      authorize AchievementRequest, :initiate?
      @sub_divisions = supervised_sub_divisions.order(:name)
      @selected_sub_division = if params[:sub_division_id].present?
        @sub_divisions.find_by(id: params[:sub_division_id])
      end

      scope = AchievementRequest.for_current_reviewer(current_user)
                                .includes(:student, :current_review_role, category: :sub_division, req_histories: :actor)
                                .order(created_at: :desc)
      if @selected_sub_division
        scope = scope.joins(category: :sub_division)
                     .where(sub_divisions: { id: @selected_sub_division.id })
      end
      @requests = scope
    end
  end
end
