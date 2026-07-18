require "rails_helper"

RSpec.describe "Admin users", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "creates a user who can then sign in" do
    expect {
      post "/admin/users", params: { user: {
        name: "New Faculty", email: "newfac@example.com", role: "faculty",
        password: "password123", password_confirmation: "password123"
      } }
    }.to change(User, :count).by(1)

    user = User.find_by(email: "newfac@example.com")
    expect(user.role).to eq("faculty")
    expect(user.password_change_required).to be true

    sign_out admin
    post "/users/sign_in", params: { user: { email: "newfac@example.com", password: "password123" } }
    expect(response).to redirect_to(root_path)
  end

  it "updates a user without changing the password when fields are left blank" do
    user = create(:user, :faculty, password: "password123")

    patch "/admin/users/#{user.id}", params: { user: {
      name: "Renamed", email: user.email, role: "faculty", password: "", password_confirmation: ""
    } }

    expect(response).to redirect_to("/admin/users")
    expect(user.reload.name).to eq("Renamed")
    expect(user.valid_password?("password123")).to be true
    expect(user.password_change_required).to be false
  end

  it "forces a password change when an admin resets someone's password" do
    user = create(:user, :faculty)

    patch "/admin/users/#{user.id}", params: { user: {
      name: user.name, email: user.email, role: "faculty",
      password: "resetpass123", password_confirmation: "resetpass123"
    } }

    expect(user.reload.password_change_required).to be true
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
end
