require "rails_helper"

RSpec.describe "Admin hierarchies", type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    sign_in admin
    ReviewRole.ensure_system_roles!
    Hierarchy.ensure_defaults!
  end

  def create_custom_division_hierarchy(name: "Request Spec Hierarchy #{SecureRandom.hex(3)}")
    hierarchy = Hierarchy.create!(name: name, scope: "division", is_default: false)
    hierarchy.hierarchy_roles.create!(
      review_role: ReviewRole.dean,
      position: 1,
      can_raise_on_behalf: false
    )
    hierarchy
  end

  it "lists hierarchy templates with make-default and delete affordances" do
    custom = create_custom_division_hierarchy

    get "/admin/hierarchies"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Hierarchy templates")
    expect(response.body).to include("Make default")
    expect(response.body).to include("Current default")
    expect(response.body).to include("Rename")
    expect(response.body).to include("Delete template")
    expect(response.body).to include('data-hierarchy-name-input')
    expect(response.body).to include(make_default_admin_hierarchy_path(custom))
    expect(response.body).not_to include("Not on a template")
    expect(response.body).not_to include("data-owner-tray")
    expect(response.body).to include("Every unit stays on a template")
  end

  it "promotes a hierarchy to default without moving existing owners" do
    old_default = Hierarchy.default_for("division")
    division = create(:division)
    custom = create_custom_division_hierarchy

    post "/admin/hierarchies/#{custom.id}/make_default"

    expect(response).to redirect_to("/admin/hierarchies")
    expect(custom.reload).to be_is_default
    expect(old_default.reload).not_to be_is_default
    expect(division.reload.hierarchy_id).to eq(old_default.id)
  end

  it "deletes an empty non-default hierarchy" do
    custom = create_custom_division_hierarchy

    expect {
      delete "/admin/hierarchies/#{custom.id}"
    }.to change(Hierarchy, :count).by(-1)

    expect(response).to redirect_to("/admin/hierarchies")
  end

  it "rejects deleting a hierarchy that still has owners" do
    custom = create_custom_division_hierarchy
    division = create(:division)
    division.update!(hierarchy: custom)

    expect {
      delete "/admin/hierarchies/#{custom.id}"
    }.not_to change(Hierarchy, :count)

    expect(response).to redirect_to("/admin/hierarchies")
    expect(flash[:alert]).to include("still in use")
  end

  it "rejects deleting the default hierarchy" do
    default = Hierarchy.default_for("division")

    expect {
      delete "/admin/hierarchies/#{default.id}"
    }.not_to change(Hierarchy, :count)

    expect(response).to redirect_to("/admin/hierarchies")
    expect(flash[:alert]).to include("cannot be deleted")
  end
end
