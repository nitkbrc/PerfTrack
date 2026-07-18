module Deans
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_dean

    private

    def deaned_divisions
      current_user.deaned_divisions
    end
    helper_method :deaned_divisions

    def require_dean
      return if current_user.faculty? && deaned_divisions.exists?

      redirect_to root_path, alert: "You are not authorized to do that."
    end
  end
end
