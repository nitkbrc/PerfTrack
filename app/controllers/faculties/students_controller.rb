module Faculties
  class StudentsController < BaseController
    def index
      authorize ::Student
      @students = ::Student.includes(:user, :department).joins(:user).order("users.name")
      @scores = ::Student.overall_scores
    end

    def show
      @student = authorize ::Student.find(params[:id])

      approved = @student.achievement_requests.dean_approved
                         .includes(category: { sub_division: :division })
                         .order(updated_at: :desc)
      @positive_requests, @negative_requests = approved.partition { |r| r.points_awarded.positive? }
      @positive_total = @positive_requests.sum(&:points_awarded)
      @negative_total = @negative_requests.sum(&:points_awarded)
    end
  end
end
