module Supervisors
  class ReviewHistoriesController < BaseController
    def index
      authorize AchievementRequest, :initiate?
      @histories = ReqHistory.review_actions.by_actor(current_user)
                             .includes(request_version: { achievement_request: :student })
                             .order(created_at: :desc)
    end
  end
end
