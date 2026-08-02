module Deans
  class DashboardController < BaseController
    def index
      authorize AchievementRequest, :dean_queue?

      scope = scoped_requests
      @divisions = deaned_divisions
                     .includes(sub_divisions: [ :categories ])
                     .order(:name)

      @awaiting_decision = AchievementRequest.for_current_reviewer(current_user).count
      @accepted = scope.approved.count
      @rejected = scope.rejected.count
      @history_count = ReqHistory.review_actions.by_actor(current_user).count

      @student_count = Student.count
      @department_count = Department.count
      @faculty_count = User.faculty.count
    end

    private

    def scoped_requests
      AchievementRequest.joins(category: { sub_division: :division })
                        .where(divisions: { id: current_user.assigned_divisions.select(:id) })
    end
  end
end
