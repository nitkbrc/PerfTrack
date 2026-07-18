module Admin
  class BaseController < ApplicationController
    layout "admin"

    before_action :authenticate_user!

    rescue_from ActiveRecord::InvalidForeignKey do
      redirect_back fallback_location: admin_root_path,
                    alert: "Cannot delete — it is still in use."
    end
  end
end
