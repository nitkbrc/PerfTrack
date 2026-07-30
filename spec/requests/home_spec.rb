require "rails_helper"

RSpec.describe "Home", type: :request do
  it "renders the landing page for guests" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Welcome to SCATS")
  end

  it "redirects a signed-in faculty member to the faculty dashboard" do
    sign_in create(:user, :faculty)

    get root_path

    expect(response).to redirect_to(faculty_root_path)
  end

  it "redirects a signed-in admin to the admin panel" do
    sign_in create(:user, :admin)

    get root_path

    expect(response).to redirect_to(admin_root_path)
  end
end
