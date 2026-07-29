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
    expect(response.body).to include("Are you sure you want to sign out?")
  end

  it "lists divisions a dean is responsible for" do
    dean = create(:user, :faculty, name: "Dean Mehta")
    create(:division, name: "Cultural & Sports", dean: dean)
    sign_in dean

    get profile_path

    expect(response.body).to include("Dean of division")
    expect(response.body).to include("Cultural &amp; Sports")
  end

  it "lists sub-divisions a supervisor is responsible for" do
    supervisor = create(:user, :faculty, name: "Prof. Iyer")
    division = create(:division, name: "Technical")
    create(:sub_division, name: "Coding Club", division: division, supervisor: supervisor)
    sign_in supervisor

    get profile_path

    expect(response.body).to include("Supervisor of sub-division")
    expect(response.body).to include("Coding Club")
    expect(response.body).to include("Technical")
  end

  it "notes system-wide responsibility for admins" do
    admin = create(:user, :admin, name: "Admin One")
    sign_in admin

    get profile_path

    expect(response.body).to include("System-wide administration")
  end
end
