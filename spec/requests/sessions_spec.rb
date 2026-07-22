require "rails_helper"

RSpec.describe "User sessions", type: :request do
  it "sends failed sign-in back to the landing page with an alert" do
    create(:user, email: "asha@example.com", password: "password123")

    post user_session_path, params: { user: { email: "asha@example.com", password: "wrong" } }

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("Welcome to SCATS")
    expect(response.body).to include("Invalid")
  end

  it "redirects the standalone sign-in page to the landing page" do
    get new_user_session_path

    expect(response).to redirect_to(root_path)
  end
end
