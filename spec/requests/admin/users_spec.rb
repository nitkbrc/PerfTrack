require "rails_helper"

RSpec.describe "Admin users", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:photo) { fixture_file_upload("proof.png", "image/png") }

  def user_attrs(overrides = {})
    {
      name: "New Faculty",
      email: "newfac@example.com",
      role: "faculty",
      phone: "9876543210",
      address: "123 Campus Road",
      photo: photo,
      password: "password123",
      password_confirmation: "password123"
    }.merge(overrides)
  end

  before { sign_in admin }

  it "does not show a New user button on the users index" do
    get admin_users_path

    expect(response.body).not_to include("New user")
  end

  it "opens the edit user form inside the modal turbo frame" do
    user = create(:user, :faculty)

    get edit_admin_user_path(user)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="modal"')
    expect(response.body).to include('data-controller="modal"')
    expect(response.body).to include("Edit user")
  end

  it "targets the modal frame from user row clicks on the index" do
    user = create(:user, :faculty, email: "rowclick@example.com")

    get admin_users_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="modal"')
    expect(response.body).to include('data-turbo-frame="modal"')
    expect(response.body).to include(edit_admin_user_path(user))
    expect(response.body).to include("Edit #{user.name.presence || user.email}")
    expect(response.body).not_to match(/>\s*Edit\s*</)
  end

  it "redirects new user to the import users page" do
    get new_admin_user_path

    expect(response).to redirect_to(new_admin_user_import_path)
  end

  it "creates a user who can then sign in" do
    expect {
      post "/admin/users", params: { user: user_attrs }
    }.to change(User, :count).by(1)

    user = User.find_by(email: "newfac@example.com")
    expect(user.role).to eq("faculty")
    expect(user.phone).to eq("9876543210")
    expect(user.address).to eq("123 Campus Road")
    expect(user.photo).to be_attached
    expect(user.password_change_required).to be true

    sign_out admin
    post "/users/sign_in", params: { user: { email: "newfac@example.com", password: "password123" } }
    expect(response).to redirect_to(root_path)
  end

  it "updates a user without changing the password when fields are left blank" do
    user = create(:user, :faculty, password: "password123")

    patch "/admin/users/#{user.id}", params: { user: user_attrs(
      name: "Renamed", email: user.email, password: "", password_confirmation: ""
    ).except(:photo) }

    expect(response).to redirect_to("/admin/users")
    user.reload
    expect(user.name).to eq("Renamed")
    expect(user.valid_password?("password123")).to be true
    expect(user.password_change_required).to be false
    expect(user.photo).to be_attached
  end

  it "does not allow changing a user's role on update" do
    user = create(:user, :student)

    patch "/admin/users/#{user.id}", params: { user: user_attrs(
      name: user.name, email: user.email, role: "admin",
      password: "", password_confirmation: ""
    ).except(:photo) }

    expect(response).to redirect_to("/admin/users")
    expect(user.reload.role).to eq("student")
  end

  it "shows role as read-only on the edit form" do
    user = create(:user, :student)

    get edit_admin_user_path(user)

    expect(response.body).to include("Role is set at creation and cannot be changed")
    expect(response.body).not_to include('id="user_role"')
    expect(response.body).not_to include("data-controller=\"segmented-switch\"")
  end

  it "forces a password change when an admin resets someone's password" do
    user = create(:user, :faculty)

    patch "/admin/users/#{user.id}", params: { user: user_attrs(
      name: user.name, email: user.email,
      password: "resetpass123", password_confirmation: "resetpass123"
    ).except(:photo) }

    expect(user.reload.password_change_required).to be true
  end

  it "creates a student user together with their Student profile" do
    department = create(:department)

    expect {
      post "/admin/users", params: { user: user_attrs(
        name: "New Student", email: "newstud@example.com", role: "student",
        student_profile_attributes: { usn: "1XX23CS999", department_id: department.id, sem: 5 }
      ) }
    }.to change(User, :count).by(1).and change(Student, :count).by(1)

    profile = User.find_by(email: "newstud@example.com").student_profile
    expect(profile.usn).to eq("1XX23CS999")
    expect(profile.department).to eq(department)
  end

  it "ignores student profile params for non-student roles" do
    expect {
      post "/admin/users", params: { user: user_attrs(
        name: "New Faculty 2", email: "newfac2@example.com",
        student_profile_attributes: { usn: "", department_id: "", sem: "" }
      ) }
    }.to change(User, :count).by(1)

    expect(User.find_by(email: "newfac2@example.com").student_profile).to be_nil
  end

  it "prevents an admin from deleting their own account" do
    expect {
      delete "/admin/users/#{admin.id}"
    }.not_to change(User, :count)

    expect(response).to redirect_to("/admin/users")
    expect(flash[:alert]).to eq("You cannot delete your own account.")
  end

  it "deletes another user" do
    user = create(:user, :faculty)

    expect {
      delete "/admin/users/#{user.id}"
    }.to change(User, :count).by(-1)
  end

  it "no longer exposes public signup" do
    get "/users/sign_up"

    expect(response).to have_http_status(:not_found)
  end

  it "filters users by supervisor assignment" do
    supervisor = create(:sub_division).supervisor
    create(:user, :faculty)

    get admin_users_path, params: { role: "supervisor" }

    expect(response.body).to include(supervisor.email)
  end

  it "shows Supervisor under Role for faculty who supervise a sub-division" do
    supervisor = create(:sub_division).supervisor
    plain_faculty = create(:user, :faculty, email: "plainfac@example.com")

    get admin_users_path

    expect(response.body).to include(supervisor.email)
    expect(response.body).to include("Supervisor")
    expect(response.body).to include(plain_faculty.email)
    expect(response.body).to include("Faculty")
  end

  it "shows Dean under Role for faculty who dean a division" do
    dean = create(:division).dean

    get admin_users_path

    expect(response.body).to include(dean.email)
    expect(response.body).to include("Dean")
  end

  it "filters students by department, semester, and search" do
    department = create(:department, name: "CSE")
    student = create(:student, usn: "1XX22CS050", department: department, sem: 3)
    other = create(:student, usn: "1XX22EC001")

    get admin_users_path, params: { role: "student", department_id: department.id, sem: 3, q: "1XX22CS050" }

    expect(response.body).to include(student.user.email)
    expect(response.body).not_to include(other.user.email)
  end
end
