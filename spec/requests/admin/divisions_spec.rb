require "rails_helper"

RSpec.describe "Admin divisions", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "creates a division through the wizard with hierarchy staffing" do
    Hierarchy.ensure_defaults!
    hierarchy = Hierarchy.default_for("division")
    dean = create(:user, :faculty)

    expect {
      post "/admin/divisions", params: {
        division: { name: "Sports", div_type: "positive", hierarchy_id: hierarchy.id },
        assignments: { hierarchy.hierarchy_roles.first.review_role_id.to_s => dean.id }
      }
    }.to change(Division, :count).by(1)

    expect(response).to redirect_to("/admin/divisions")
    expect(Division.find_by!(name: "Sports").dean).to eq(dean)
  end

  it "opens the multi-step create division wizard" do
    get "/admin/divisions/new"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="owner-create-wizard"')
    expect(response.body).to include("Create a division")
    expect(response.body).to include("Choose a hierarchy")
    expect(response.body).to include("Assign people")
    expect(response.body).to include("Positive")
    expect(response.body).to include("Negative")
  end

  it "links to the full-page create wizard from the divisions index" do
    get "/admin/divisions"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(new_admin_division_path)
    expect(response.body).to include('aria-label="Create division"')
  end

  it "shows restore and delete only on the archived divisions list" do
    active = create(:division, name: "Active Sports")
    archived = create(:division, name: "Old Sports")
    archived.archive!

    get "/admin/divisions"
    expect(response.body).to include("Archive")
    expect(response.body).not_to include("Delete")

    get "/admin/divisions?archived=1"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Restore")
    expect(response.body).to include("Delete")
    expect(response.body).to include(restore_admin_division_path(archived))
    expect(response.body).to include(admin_division_path(archived))
    expect(response.body).not_to include(admin_division_path(active) + "/edit")
  end

  it "refuses to permanently delete an active division" do
    division = create(:division)

    expect {
      delete "/admin/divisions/#{division.id}", headers: { "HTTP_REFERER" => "/admin/divisions?archived=1" }
    }.not_to change(Division, :count)

    expect(response).to redirect_to("/admin/divisions?archived=1")
    expect(flash[:alert]).to include("Only archived divisions")
  end

  it "permanently deletes an archived division with no approved requests" do
    division = create(:division)
    sub = create(:sub_division, division: division)
    category = create(:category, sub_division: sub)
    create(:achievement_request, :rejected, category: category)
    division.archive!

    expect {
      delete "/admin/divisions/#{division.id}"
    }.to change(Division, :count).by(-1)
      .and change(SubDivision, :count).by(-1)
      .and change(Category, :count).by(-1)

    expect(response).to redirect_to("/admin/divisions?archived=1")
    expect(flash[:notice]).to include("permanently deleted")
  end

  it "refuses to permanently delete an archived division that has approved requests" do
    division = create(:division)
    sub = create(:sub_division, division: division)
    category = create(:category, sub_division: sub)
    create(:achievement_request, :approved, category: category)
    division.archive!

    expect {
      delete "/admin/divisions/#{division.id}"
    }.not_to change(Division, :count)

    expect(response).to redirect_to("/admin/divisions?archived=1")
    expect(flash[:alert]).to include("approved request history")
  end

  it "shows a division's sub-divisions" do
    division = create(:division, name: "Sports")
    sub_division = create(:sub_division, division: division, name: "Athletics")

    get admin_division_path(division)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(sub_division.name)
  end

  it "shows the division hierarchy panel on the right" do
    dean = create(:user, :faculty, name: "Dean Alice")
    division = create(:division, name: "Sports", dean: dean)

    get admin_division_path(division)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Review hierarchy")
    expect(response.body).to include(division.hierarchy.name)
    expect(response.body).to include("Dean")
    expect(response.body).to include("Dean Alice")
    expect(response.body).to include("Assign people")
  end

  it "shows categories for a sub-division" do
    sub_division = create(:sub_division, name: "Athletics")
    category = create(:category, sub_division: sub_division, name: "Gold medal")

    get admin_sub_division_path(sub_division)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(category.name)
    expect(response.body).to include("+")
  end

  it "shows the sub-division hierarchy panel on the right" do
    supervisor = create(:user, :faculty, name: "Supervisor Bob")
    sub_division = create(:sub_division, name: "Athletics", supervisor: supervisor)

    get admin_sub_division_path(sub_division)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Review hierarchy")
    expect(response.body).to include(sub_division.hierarchy.name)
    expect(response.body).to include("Supervisor")
    expect(response.body).to include("Supervisor Bob")
    expect(response.body).to include("Assign people")
  end
end
