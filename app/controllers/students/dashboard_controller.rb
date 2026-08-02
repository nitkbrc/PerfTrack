module Students
  class DashboardController < BaseController
    def index
      authorize AchievementRequest, :index?
      @requests = policy_scope(AchievementRequest)
                    .includes(category: { sub_division: :division },
                              req_histories: :actor,
                              request_versions: { req_histories: :actor })
                    .order(created_at: :desc)

      @score               = current_student.overall_score
      @achievement_count   = @requests.count { |r| r.approved? && r.category.sub_division.division.positive? }
      @achievement_points  = current_student.positive_total
      @conduct_points      = current_student.negative_total.abs
      @critical_warnings   = @requests.count(&:reverted?)
    end
  end
end
