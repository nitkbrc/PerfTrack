module Supervisors
  class QueueController < BaseController
    def index
      authorize AchievementRequest, :initiate?
      # dean_reverted requests come back to the supervisor for clarification
      # and re-forwarding (PRD section 6 lifecycle).
      @requests = policy_scope(AchievementRequest)
                    .where(status: [ :submitted, :dean_reverted ])
                    .includes(:student, category: :sub_division)
                    .order(:created_at)
    end
  end
end
