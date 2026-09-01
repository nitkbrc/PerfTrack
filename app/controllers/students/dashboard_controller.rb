module Students
  class DashboardController < BaseController
    def index
      authorize AchievementRequest, :index?
      all_requests = policy_scope(AchievementRequest)
                        .includes(category: { sub_division: :division },
                                  req_histories: :actor,
                                  request_versions: { req_histories: :actor })
                        .order(created_at: :desc)

      @requests = all_requests.select { |r| r.in_review? || r.reverted? }
      @score               = current_student.overall_score
      @achievement_count   = all_requests.count { |r| r.approved? && r.points_awarded.to_i > 0 }
      @achievement_points  = current_student.positive_total
      @conduct_points      = current_student.negative_total.abs
      @critical_warnings   = @requests.count(&:reverted?)
    end
  end
end
