module Admin
  class BaseController < ApplicationController
    layout "admin"

    before_action :authenticate_user!

    rescue_from ActiveRecord::InvalidForeignKey do |exception|
      # Postgres names the referencing table in the error detail
      # (`... is still referenced from table "sub_divisions"`), so tell the
      # admin what is blocking the deletion when we can.
      blocker = exception.message[/referenced from table "(\w+)"/, 1]
      alert = if blocker
        "Cannot delete — #{blocker.humanize.downcase} still belong to it. Remove or reassign them first."
      else
        "Cannot delete — it is still in use."
      end
      redirect_back fallback_location: admin_root_path, alert: alert
    end
  end
end
