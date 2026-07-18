module Deans
  class QueueController < BaseController
    def index
      authorize AchievementRequest, :dean_queue?
      @requests = policy_scope(AchievementRequest)
                    .supervisor_approved
                    .includes(:student, category: :sub_division)
                    .order(:updated_at)
    end
  end
end
