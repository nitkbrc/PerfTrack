# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # Standalone /users/sign_in is retired — sign-in lives on the landing page.
  def new
    flash.keep
    redirect_to root_path
  end

  def create
    self.resource = warden.authenticate(auth_options)

    if resource
      set_flash_message!(:notice, :signed_in) if is_flashing_format?
      sign_in(resource_name, resource)
      yield resource if block_given?
      respond_with resource, location: after_sign_in_path_for(resource)
    else
      # Failed attempt: stay on SCATS landing, not devise/sessions/new.
      redirect_to root_path,
                  alert: t("devise.failure.invalid", authentication_keys: User.human_attribute_name(:email)),
                  status: :see_other
    end
  end
end
