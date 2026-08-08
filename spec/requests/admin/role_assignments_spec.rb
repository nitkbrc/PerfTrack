require "rails_helper"

RSpec.describe "Admin role assignments", type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    ReviewRole.ensure_system_roles!
    Hierarchy.ensure_defaults!
    sign_in admin
  end

  def attach_extra_division_role(division)
    mid = ReviewRole.find_or_create_by!(name: "Division Reviewer Slot Spec") do |role|
      role.scope = "division"
      role.system_role = false
      role.raiseable_on_behalf_eligible = false
    end

    hierarchy = Hierarchy.create!(
      name: "Role Assignments Spec #{SecureRandom.hex(4)}",
      scope: "division",
      is_default: false
    )
    hierarchy.hierarchy_roles.create!(review_role: mid, position: 1, can_raise_on_behalf: false)
    hierarchy.hierarchy_roles.create!(review_role: ReviewRole.dean, position: 2, can_raise_on_behalf: false)
    hierarchy.normalize_positions!
    division.update!(hierarchy: hierarchy)
    mid
  end

  it "renders vacant slots from the owner's hierarchy template" do
    dean = create(:user, :faculty)
    division = create(:division, name: "Engineering", dean: dean)
    mid = attach_extra_division_role(division)

    get admin_role_assignments_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Engineering")
    expect(response.body).to include(mid.name)
    expect(response.body).to include("Vacant")
    expect(response.body).to include("Assign")
    expect(response.body).not_to include("Assign role")
    expect(response.body).to include('data-controller="tree vacancy-filter"')
  end

  it "redirects new without a role and owner back to the index" do
    get new_admin_role_assignment_path

    expect(response).to redirect_to(admin_role_assignments_path)
    follow_redirect!
    expect(response.body).to include("Pick a vacant role slot")
  end

  it "opens the assign modal for a specific vacant slot" do
    dean = create(:user, :faculty)
    division = create(:division, dean: dean)
    mid = attach_extra_division_role(division)

    get new_admin_role_assignment_path(review_role_id: mid.id, division_id: division.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="modal"')
    expect(response.body).to include(mid.name)
    expect(response.body).to include(division.name)
    expect(response.body).to include("Faculty")
    expect(response.body).not_to include("Select role")
  end
end
