module Faculties
  class StudentsController < BaseController
    def index
      authorize ::Student
      @students = ::Student.includes(:department, user: { photo_attachment: :blob })
                          .joins(:user).order("users.name")
      @students = @students.where(department_id: params[:department_id]) if params[:department_id].present?
      @students = @students.where(sem: params[:sem]) if params[:sem].present?
      if params[:q].present?
        term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].strip)}%"
        @students = @students.where(
          "users.name ILIKE :term OR users.email ILIKE :term OR students.usn ILIKE :term",
          term: term
        )
      end
      @departments = Department.order(:name)
      @scores = ::Student.overall_scores
    end

    def show
      @student = authorize ::Student.includes(:department, user: { photo_attachment: :blob })
                                    .find(params[:id])

      approved = @student.achievement_requests.dean_approved
                         .includes(category: { sub_division: :division })
                         .order(updated_at: :desc)
      @positive_requests, @negative_requests = approved.partition { |r| r.points_awarded.positive? }
      @positive_total = @positive_requests.sum(&:points_awarded)
      @negative_total = @negative_requests.sum(&:points_awarded)
    end
  end
end
