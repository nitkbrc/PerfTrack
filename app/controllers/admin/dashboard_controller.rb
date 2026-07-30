module Admin
  class DashboardController < BaseController
    def index
      authorize Division

      @department_count = Department.count
      @division_count = Division.active.count
      @sub_division_count = SubDivision.active.count
      @category_count = Category.active.count
      @reason_template_count = ReasonTemplate.count
      @user_count = User.count
      @student_count = User.student.count
      @faculty_count = User.faculty.count
    end
  end
end
