module Admin
  class SettingsController < BaseController
    def edit
      @setting = authorize Setting.instance
      @permissions_by_action = Permission.grouped_by_action
    end

    def update
      @setting = authorize Setting.instance
      @permissions_by_action = Permission.grouped_by_action

      ActiveRecord::Base.transaction do
        @setting.update!(setting_params) if params[:setting].present?
        update_permissions! if params[:permissions].present?
      end

      redirect_to edit_admin_settings_path, notice: "Settings saved."
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    private

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
  end
end
