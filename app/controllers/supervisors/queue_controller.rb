module Supervisors
  class QueueController < BaseController
    def index
      authorize AchievementRequest, :initiate?
      @requests = policy_scope(AchievementRequest)
                    .submitted
                    .includes(:student, category: :sub_division)
                    .order(:created_at)
    end
  end
end
