class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Fail loudly if a non-Devise action never called authorize.
  after_action :verify_authorized, unless: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Admin-created accounts must replace their temporary password before doing
  # anything else. Devise controllers stay reachable so the user can sign out.
  before_action :enforce_password_change, unless: :devise_controller?

  private

  def enforce_password_change
    return unless user_signed_in? && current_user.password_change_required?

    redirect_to edit_account_password_path, alert: "Please set a new password to continue."
  end

  def user_not_authorized
    redirect_to root_path, alert: "You are not authorized to do that."
  end
end
