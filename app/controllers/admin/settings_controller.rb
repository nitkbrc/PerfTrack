module Admin
  class SettingsController < BaseController
    before_action :load_setting, only: [ :edit, :score_scale, :role_permissions, :update ]

    def edit
      authorize @setting
    end

    def score_scale
      authorize @setting, :edit?
    end

    def role_permissions
      authorize @setting, :edit?
      Permission.ensure_defaults!
      ReviewRole.ensure_system_roles!
      @permissions_by_role = Permission.grouped_by_role
      @review_roles = ReviewRole.order(:scope, :name)
    end

    def update
      authorize @setting
      load_role_permissions_collections if role_permissions_form?

      ActiveRecord::Base.transaction do
        @setting.update!(setting_params) if params[:setting].present?
        update_permissions! if params[:permissions].present?
        update_review_role_student_create! if params[:review_roles].present?
      end

      redirect_to settings_return_path, notice: "Settings saved."
    rescue ActiveRecord::RecordInvalid
      render settings_error_template, status: :unprocessable_entity
    end

    private

    def load_setting
      @setting = Setting.instance
    end

    def role_permissions_form?
      params[:form].to_s.in?(%w[role_permissions profile_permissions])
    end

    def load_role_permissions_collections
      Permission.ensure_defaults!
      ReviewRole.ensure_system_roles!
      @permissions_by_role = Permission.grouped_by_role
      @review_roles = ReviewRole.order(:scope, :name)
    end

    def setting_params
      params.expect(setting: [ :score_scale_k ])
    end

    def update_permissions!
      params.require(:permissions).each do |id, attrs|
        permission = Permission.find(id)
        authorize permission, :update?
        permission.update!(enabled: cast_checkbox(attrs[:enabled]))
      end
    end

    def update_review_role_student_create!
      params.require(:review_roles).each do |id, attrs|
        role = ReviewRole.find(id)
        authorize role, :update?
        role.update!(can_create_students: cast_checkbox(attrs[:can_create_students]))
      end
    end

    # Rails checkbox + companion hidden can arrive as "0"/"1" or ["0","1"].
    def cast_checkbox(value)
      value = Array(value).last
      ActiveModel::Type::Boolean.new.cast(value)
    end

    def settings_return_path
      case params[:form]
      when "score_scale" then score_scale_admin_settings_path
      when "role_permissions", "profile_permissions" then role_permissions_admin_settings_path
      else edit_admin_settings_path
      end
    end

    def settings_error_template
      case params[:form]
      when "score_scale" then :score_scale
      when "role_permissions", "profile_permissions" then :role_permissions
      else :edit
      end
    end
  end
end
