require "rails_helper"

RSpec.describe "Admin review roles", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "opens the new review role form inside the modal turbo frame" do
    get "/admin/review_roles/new"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="modal"')
    expect(response.body).to include('data-controller="modal"')
    expect(response.body).to include("New review role")
    expect(response.body).to include("Name")
  end

  it "opens the edit form inside the modal turbo frame" do
    role = ReviewRole.supervisor

    get "/admin/review_roles/#{role.id}/edit"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="modal"')
    expect(response.body).to include("Edit review role")
  end

  it "creates a custom review role" do
    expect {
      post "/admin/review_roles", params: {
        review_role: {
          name: "Coordinator",
          scope: "sub_division",
          raiseable_on_behalf_eligible: "1"
        }
      }
    }.to change(ReviewRole, :count).by(1)

    expect(response).to redirect_to("/admin/review_roles")
    expect(ReviewRole.find_by!(name: "Coordinator")).not_to be_system_role
  end

  it "bulk-saves raise-on-behalf toggles from the index" do
    on_role = ReviewRole.create!(
      name: "Bulk On Spec",
      scope: "sub_division",
      raiseable_on_behalf_eligible: false,
      system_role: false
    )
    off_role = ReviewRole.create!(
      name: "Bulk Off Spec",
      scope: "sub_division",
      raiseable_on_behalf_eligible: true,
      system_role: false
    )

    post "/admin/review_roles/bulk_save", params: {
      roles: {
        on_role.id.to_s => { raiseable_on_behalf_eligible: "1" },
        off_role.id.to_s => { raiseable_on_behalf_eligible: "0" }
      }
    }

    expect(response).to redirect_to("/admin/review_roles")
    expect(on_role.reload).to be_raiseable_on_behalf_eligible
    expect(off_role.reload).not_to be_raiseable_on_behalf_eligible
  end

  it "shows staged raiseable toggles and a bulk save bar on the index" do
    get "/admin/review_roles"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Raise on behalf")
    expect(response.body).to include('data-controller="review-roles"')
    expect(response.body).to include("data-raiseable-toggle")
    expect(response.body).to include("Save changes")
    expect(response.body).to include(bulk_save_admin_review_roles_path)
  end

  it "returns not found for a bogus show-style path without an id" do
    get "/admin/review_roles/edit"

    expect(response).to have_http_status(:not_found)
  end
end
