# Pages for any faculty member, with or without supervisor/dean assignments.
module Faculties
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_faculty

    private

    def require_faculty
      return if current_user.faculty?

      redirect_to root_path, alert: "You are not authorized to do that."
    end
  end
end
