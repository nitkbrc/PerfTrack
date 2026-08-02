module Supervisors
  class DashboardController < BaseController
    def index
      authorize AchievementRequest, :initiate?

      scope = scoped_requests
      @sub_divisions = supervised_sub_divisions
                         .includes(:categories)
                         .order(:name)

      @pending_reviews = AchievementRequest.for_current_reviewer(current_user).count
      @accepted_by_dean = scope.approved.count
      @rejected = scope.rejected.count
      @history_count = ReqHistory.review_actions.by_actor(current_user).count

      @student_count = Student.count
      @department_count = Department.count
      @faculty_count = User.faculty.count
    end

    private

    def scoped_requests
      AchievementRequest.joins(category: :sub_division)
                        .where(sub_divisions: { id: current_user.assigned_sub_divisions.select(:id) })
    end
  end
end
