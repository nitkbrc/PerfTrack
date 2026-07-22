require "rails_helper"

RSpec.describe "Account passwords", type: :request do
  describe "forced password change" do
    let(:user) { create(:user, :faculty, password: "temp123456", password_change_required: true) }

    before { sign_in user }

    it "redirects every page to the change-password form until the password is changed" do
      get root_path

      expect(response).to redirect_to(edit_account_password_path)
      expect(flash[:alert]).to eq("Please set a new password to continue.")
    end

    it "renders the change-password form itself without redirecting" do
      get edit_account_password_path

      expect(response).to have_http_status(:ok)
    end

    it "still allows signing out" do
      delete destroy_user_session_path

      expect(response).to redirect_to(root_path)
    end

    it "clears the flag after a successful change and unlocks the app" do
      put account_password_path, params: { user: {
        current_password: "temp123456", password: "mynewpass99", password_confirmation: "mynewpass99"
      } }

      expect(response).to redirect_to(root_path)
      expect(user.reload.password_change_required).to be false
      expect(user.valid_password?("mynewpass99")).to be true

      get root_path
      expect(response).to redirect_to(faculty_root_path)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end
  end

  describe "voluntary password change" do
    let(:user) { create(:user, :faculty, password: "password123") }

    before { sign_in user }

    it "changes the password and keeps the user signed in" do
      put account_password_path, params: { user: {
        current_password: "password123", password: "anotherpass1", password_confirmation: "anotherpass1"
      } }

      expect(response).to redirect_to(root_path)
      expect(user.reload.valid_password?("anotherpass1")).to be true

      get root_path
      expect(response).to redirect_to(faculty_root_path)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it "rejects a wrong current password" do
      put account_password_path, params: { user: {
        current_password: "wrong", password: "anotherpass1", password_confirmation: "anotherpass1"
      } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.valid_password?("password123")).to be true
    end

    it "rejects a blank new password" do
      put account_password_path, params: { user: {
        current_password: "password123", password: "", password_confirmation: ""
      } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.valid_password?("password123")).to be true
    end

    it "requires sign-in" do
      sign_out user
      get edit_account_password_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
