require "rails_helper"

RSpec.describe "Profile", type: :request do
  it "shows the signed-in user's view-only profile" do
    user = create(:user, :faculty, name: "Prof. Rao")
    sign_in user

    get profile_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Prof. Rao")
    expect(response.body).to include("Change password")
    expect(response.body).to include("Sign out")
  end
end
