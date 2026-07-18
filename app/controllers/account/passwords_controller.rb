module Account
  class PasswordsController < ApplicationController
    before_action :authenticate_user!
    skip_before_action :enforce_password_change

    # The record is always current_user, so there is no policy decision to make.
    skip_after_action :verify_authorized

    def edit
      @user = current_user
    end

    def update
      @user = current_user

      if password_params[:password].blank?
        @user.errors.add(:password, "can't be blank")
        return render :edit, status: :unprocessable_content
      end

      if @user.update_with_password(password_params)
        @user.update_column(:password_change_required, false)
        # Changing the password invalidates the session, so re-sign in transparently.
        bypass_sign_in(@user)
        redirect_to root_path, notice: "Your password has been changed."
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def password_params
      params.expect(user: [ :current_password, :password, :password_confirmation ])
    end
  end
end
