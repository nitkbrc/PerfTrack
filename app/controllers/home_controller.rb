class HomeController < ApplicationController
  # Public landing page — no resource to authorize.
  skip_after_action :verify_authorized

  def index
    return unless user_signed_in?

    redirect_to home_destination
  end

  private

  def home_destination
    return admin_root_path if current_user.admin?
    return student_root_path if current_user.student?
    return supervisor_root_path if current_user.supervised_sub_divisions.exists?
    return dean_root_path if current_user.deaned_divisions.exists?

    faculty_root_path
  end
end
