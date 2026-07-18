module Admin
  class UsersController < BaseController
    def index
      authorize User
      @users = User.order(:name)
    end

    def new
      @user = authorize User.new
    end

    def create
      @user = authorize User.new(user_params)
      # Admin knows the initial password, so the user must pick their own on first login.
      @user.password_change_required = true
      if @user.save
        redirect_to admin_users_path, notice: "User created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @user = authorize User.find(params[:id])
    end

    def update
      @user = authorize User.find(params[:id])
      # An admin password reset also forces the user to pick their own (except on self-edits).
      @user.password_change_required = true if user_params[:password].present? && @user != current_user
      if @user.update(user_update_params)
        redirect_to admin_users_path, notice: "User updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      user = authorize User.find(params[:id])
      if user == current_user
        redirect_to admin_users_path, alert: "You cannot delete your own account."
      else
        user.destroy!
        redirect_to admin_users_path, notice: "User deleted."
      end
    end

    private

    def user_params
      permitted = params.expect(user: [ :name, :email, :role, :password, :password_confirmation,
                                        { student_profile_attributes: [ :id, :usn, :department_id, :sem ] } ])
      # The profile fieldset is only meaningful for students; drop stray params
      # submitted while the fieldset was hidden.
      permitted.delete(:student_profile_attributes) unless permitted[:role] == "student"
      permitted
    end

    # Leaving the password fields blank on edit keeps the current password.
    def user_update_params
      permitted = user_params
      if permitted[:password].blank?
        permitted.except(:password, :password_confirmation)
      else
        permitted
      end
    end
  end
end
