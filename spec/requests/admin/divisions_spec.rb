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

  it "opens the new division form inside the modal turbo frame" do
    get "/admin/divisions/new"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="modal"')
    expect(response.body).to include('data-controller="modal"')
    expect(response.body).to include("New division")
    expect(response.body).to include("Name")
  end

  it "targets the modal frame from the divisions index create links" do
    get "/admin/divisions"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="modal"')
    expect(response.body).to include('data-turbo-frame="modal"')
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

  it "deletes an empty division" do
    division = create(:division)

    expect {
      delete "/admin/divisions/#{division.id}"
    }.to change(Division, :count).by(-1)

    expect(response).to redirect_to("/admin/divisions")
  end

  it "refuses to delete a division that still has sub-divisions, naming the blocker" do
    division = create(:division)
    create(:sub_division, division: division)

    expect {
      delete "/admin/divisions/#{division.id}", headers: { "HTTP_REFERER" => "/admin/divisions" }
    }.not_to change(Division, :count)

    expect(response).to redirect_to("/admin/divisions")
    expect(flash[:alert]).to eq("Cannot delete — sub divisions still belong to it. Remove or reassign them first.")
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

  it "shows a division's sub-divisions" do
    division = create(:division, name: "Sports")
    sub_division = create(:sub_division, division: division, name: "Athletics")

    get admin_division_path(division)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(sub_division.name)
  end

  it "shows categories for a sub-division" do
    sub_division = create(:sub_division, name: "Athletics")
    category = create(:category, sub_division: sub_division, name: "Gold medal")

    get admin_sub_division_path(sub_division)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(category.name)
    expect(response.body).to include("+")
  end
end
