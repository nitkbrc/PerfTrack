module Students
  class DashboardController < BaseController
    def index
      authorize AchievementRequest, :index?
      @requests = policy_scope(AchievementRequest)
                    .includes(category: { sub_division: :division }, req_histories: :actor)
                    .order(created_at: :desc)
    end
  end
end
