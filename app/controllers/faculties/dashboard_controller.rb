module Faculties
  class DashboardController < BaseController
    def index
      authorize ::Student, :index?

      @student_count = ::Student.count
      @department_count = Department.count
      @faculty_count = User.faculty.count
      @division_count = Division.active.count
      @sub_division_count = SubDivision.active.count
    end
  end
end
