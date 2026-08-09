module Admin
  class SettingsController < BaseController
    before_action :load_setting, only: [ :edit, :score_scale, :profile_permissions, :update ]

    def edit
      authorize @setting
    end

    def score_scale
      authorize @setting, :edit?
    end

    def profile_permissions
      authorize @setting, :edit?
      Permission.ensure_defaults!
      @permissions_by_role = Permission.grouped_by_role
    end

    def update
      authorize @setting
      @permissions_by_role = Permission.grouped_by_role if params[:permissions].present?

      ActiveRecord::Base.transaction do
        @setting.update!(setting_params) if params[:setting].present?
        update_permissions! if params[:permissions].present?
      end

      redirect_to settings_return_path, notice: "Settings saved."
    rescue ActiveRecord::RecordInvalid
      render settings_error_template, status: :unprocessable_entity
    end

    private

    def load_setting
      @setting = Setting.instance
    end

    def setting_params
      params.expect(setting: [ :score_scale_k ])
    end

    def update_permissions!
      params.require(:permissions).each do |id, attrs|
        permission = Permission.find(id)
        authorize permission, :update?
        permission.update!(enabled: ActiveModel::Type::Boolean.new.cast(attrs[:enabled]))
      end
    end

    def settings_return_path
      case params[:form]
      when "score_scale" then score_scale_admin_settings_path
      when "profile_permissions" then profile_permissions_admin_settings_path
      else edit_admin_settings_path
      end
    end

    def settings_error_template
      case params[:form]
      when "score_scale" then :score_scale
      when "profile_permissions" then :profile_permissions
      else :edit
      end
    end
  end
end
