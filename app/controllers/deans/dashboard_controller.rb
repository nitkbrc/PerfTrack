module Deans
  class DashboardController < BaseController
    def index
      authorize AchievementRequest, :dean_queue?

      scope = scoped_requests
      @divisions = deaned_divisions
                     .includes(sub_divisions: [ :supervisor, :categories ])
                     .order(:name)

      # Scoped to the dean's divisions.
      @awaiting_decision = scope.supervisor_approved.count
      @accepted = scope.dean_approved.count
      @rejected = scope.rejected.count
      @history_count = ReqHistory.review_actions.by_actor(current_user).count

      @student_count = Student.count
      @department_count = Department.count
      @faculty_count = User.faculty.count
    end

    private

    def scoped_requests
      AchievementRequest.joins(category: { sub_division: :division })
                        .where(divisions: { dean_user_id: current_user.id })
    end
  end
end
