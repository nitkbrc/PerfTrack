module Students
  class DashboardController < BaseController
    def index
      authorize AchievementRequest, :index?
      @requests = policy_scope(AchievementRequest)
                    .includes(category: { sub_division: :division })
                    .order(created_at: :desc)
    end
  end
end
