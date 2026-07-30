module Supervisors
  class DashboardController < BaseController
    def index
      authorize AchievementRequest, :initiate?

      scope = scoped_requests
      @sub_divisions = supervised_sub_divisions
                         .includes(:categories)
                         .order(:name)

      # Scoped to the supervisor's sub-divisions.
      @pending_reviews = scope.where(status: [ :submitted, :dean_reverted ]).count
      @accepted_by_dean = scope.dean_approved.count
      @rejected = scope.rejected.count
      @history_count = ReqHistory.review_actions.by_actor(current_user).count

      @student_count = Student.count
      @department_count = Department.count
      @faculty_count = User.faculty.count
    end

    private

    def scoped_requests
      AchievementRequest.joins(category: :sub_division)
                        .where(sub_divisions: { supervisor_user_id: current_user.id })
    end
  end
end
