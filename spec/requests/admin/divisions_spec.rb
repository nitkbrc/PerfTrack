require "rails_helper"

RSpec.describe "Admin divisions", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "creates a division with a free faculty dean" do
    dean = create(:user, :faculty)

    expect {
      post "/admin/divisions", params: { division: { name: "Sports", div_type: "positive", dean_user_id: dean.id } }
    }.to change(Division, :count).by(1)

    expect(response).to redirect_to("/admin/divisions")
  end

  it "re-renders with a friendly error when the dean already deans another division" do
    dean = create(:user, :faculty)
    create(:division, dean: dean)

    post "/admin/divisions", params: { division: { name: "Second", div_type: "positive", dean_user_id: dean.id } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("is already the dean of another division")
  end

  it "excludes existing deans and supervisors from the dean dropdown" do
    existing_dean = create(:division).dean
    supervisor = create(:sub_division).supervisor
    free_faculty = create(:user, :faculty)

    get "/admin/divisions/new"

    expect(response.body).not_to include(%(value="#{existing_dean.id}"))
    expect(response.body).not_to include(%(value="#{supervisor.id}"))
    expect(response.body).to include(%(value="#{free_faculty.id}"))
  end

  it "re-renders the form with the exclusivity error when the dean is already a supervisor" do
    supervisor = create(:user, :faculty)
    create(:sub_division, supervisor: supervisor)

    expect {
      post "/admin/divisions", params: { division: { name: "Sports", div_type: "positive", dean_user_id: supervisor.id } }
    }.not_to change(Division, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("is already a supervisor of a sub-division")
  end
end
