module Students
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_student_profile

    private

    def current_student
      current_user.student_profile
    end
    helper_method :current_student

    def require_student_profile
      return if current_user.student? && current_student.present?

      redirect_to root_path, alert: "You are not authorized to do that."
    end
  end
end
