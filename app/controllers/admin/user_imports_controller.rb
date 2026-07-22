module Admin
  class UserImportsController < BaseController
    def new
      authorize User, :create?
      @user = User.new
    end

    def create
      authorize User, :create?

      if params[:file].blank?
        redirect_to new_admin_user_import_path, alert: "Please choose a CSV file to upload."
        return
      end

      @import = UserCsvImport.new(params[:file], staff_password: params[:staff_password].presence)
      if @import.call
        render :create
      else
        redirect_to new_admin_user_import_path, alert: @import.error
      end
    end

    def template
      authorize User, :create?
      send_data UserCsvImport.template_csv, filename: "scats_users_template.csv", type: "text/csv"
    end
  end
end
