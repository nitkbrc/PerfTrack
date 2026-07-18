# Pages for any faculty member, with or without supervisor/dean assignments.
# Admins deliberately have no access to student academic records (PRD:
# admins manage structure and accounts, not student data).
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
