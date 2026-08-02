require "rails_helper"

RSpec.describe "Admin divisions", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "creates a division with name and type only" do
    expect {
      post "/admin/divisions", params: { division: { name: "Sports", div_type: "positive" } }
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
