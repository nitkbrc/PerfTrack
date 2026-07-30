require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "renders the system overview grouped by accounts and structure" do
    get admin_root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Admin console")
    expect(response.body).to include("Total users")
    expect(response.body).to include("Departments")
    expect(response.body).to include("Divisions")
    expect(response.body).to include("Sub-divisions")
    expect(response.body).to include("Categories")
    expect(response.body).to include("Reason templates")
    expect(response.body).not_to include("Open requests")
    expect(response.body).not_to include("Request pipeline")
    expect(response.body).to include(admin_divisions_path)
    expect(response.body).to include(admin_users_path)
  end
end
