module Admin
  class SettingsController < BaseController
    def edit
      @setting = authorize Setting.instance
    end

    def update
      @setting = authorize Setting.instance
      if @setting.update(setting_params)
        redirect_to edit_admin_settings_path, notice: "Settings saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def setting_params
      params.expect(setting: [ :score_scale_k ])
    end
  end
end
