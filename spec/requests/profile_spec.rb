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

    expect(response.body).to include(">DEAN<")
    expect(response.body).to include("Dean of division")
    expect(response.body).to include("Cultural &amp; Sports")
  end

  it "lists sub-divisions a supervisor is responsible for" do
    supervisor = create(:user, :faculty, name: "Prof. Iyer")
    division = create(:division, name: "Technical")
    create(:sub_division, name: "Coding Club", division: division, supervisor: supervisor)
    sign_in supervisor

    get profile_path

    expect(response.body).to include(">SUPERVISOR<")
    expect(response.body).to include("Supervisor of sub-division")
    expect(response.body).to include("Coding Club")
    expect(response.body).to include("Technical")
  end

  it "shows Faculty for unassigned faculty" do
    user = create(:user, :faculty, name: "Prof. Plain")
    sign_in user

    get profile_path

    expect(response.body).to include(">FACULTY<")
    expect(response.body).not_to include(">DEAN<")
    expect(response.body).not_to include(">SUPERVISOR<")
  end

  it "shows Student for student accounts" do
    student_user = create(:student).user
    sign_in student_user

    get profile_path

    expect(response.body).to include(">STUDENT<")
  end

  it "shows a custom review role name instead of Supervisor" do
    ReviewRole.ensure_system_roles!
    Hierarchy.ensure_defaults!
    coordinator = ReviewRole.find_or_create_by!(name: "Coordinator") do |role|
      role.scope = "sub_division"
      role.raiseable_on_behalf_eligible = true
      role.system_role = false
    end
    faculty = create(:user, :faculty, name: "Coord User")
    sub = create(:sub_division)
    hierarchy = Hierarchy.create!(name: "Coord Spec Sub #{SecureRandom.hex(4)}", scope: "sub_division")
    hierarchy.hierarchy_roles.create!(review_role: coordinator, position: 1, can_raise_on_behalf: true)
    sub.update!(hierarchy: hierarchy)
    RoleAssignment.where(sub_division: sub).delete_all
    RoleAssignment.create!(user: faculty, review_role: coordinator, sub_division: sub)
    sign_in faculty

    get profile_path

    expect(response.body).to include(">COORDINATOR<")
    expect(response.body).to include("Coordinator of sub-division")
    expect(response.body).not_to include(">SUPERVISOR<")
    expect(response.body).not_to include(">FACULTY<")
  end

  it "notes system-wide responsibility for admins" do
    admin = create(:user, :admin, name: "Admin One")
    sign_in admin

    get profile_path

    expect(response.body).to include(">ADMIN<")
    expect(response.body).to include("System-wide administration")
  end

  it "lets faculty update phone when the permission is enabled" do
    Permission.ensure_defaults!
    user = create(:user, :faculty, phone: "9100000999", address: "Old address")
    sign_in user

    patch profile_path, params: { user: { phone: "9100000888" } }

    expect(response).to redirect_to(profile_path)
    expect(user.reload.phone).to eq("9100000888")
  end

  it "rejects profile phone updates that collide with another user" do
    Permission.ensure_defaults!
    create(:user, :faculty, phone: "9100000111")
    user = create(:user, :faculty, phone: "9100000222")
    sign_in user

    patch profile_path, params: { user: { phone: "9100-000-111" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("has already been taken")
    expect(user.reload.phone).to eq("9100000222")
  end

  it "rejects student phone updates when the permission is disabled" do
    Permission.ensure_defaults!
    student_user = create(:student).user
    original_phone = student_user.phone
    sign_in student_user

    patch profile_path, params: { user: { phone: "9100000777" } }

    expect(response).to redirect_to(profile_path)
    expect(student_user.reload.phone).to eq(original_phone)
  end
end
