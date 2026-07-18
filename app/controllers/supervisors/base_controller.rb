module Supervisors
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_supervisor

    private

    def supervised_sub_divisions
      current_user.supervised_sub_divisions
    end
    helper_method :supervised_sub_divisions

    def require_supervisor
      return if current_user.faculty? && supervised_sub_divisions.exists?

      redirect_to root_path, alert: "You are not authorized to do that."
    end
  end
end
