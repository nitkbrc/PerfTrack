module Deans
  class QueueController < BaseController
    def index
      authorize AchievementRequest, :dean_queue?
      @requests = AchievementRequest.for_current_reviewer(current_user)
                    .includes(:student, :current_review_role, category: :sub_division)
                    .order(updated_at: :desc)
    end
  end
end
