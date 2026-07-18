require "rails_helper"

RSpec.describe "Admin access control", type: :request do
  let(:admin)   { create(:user, :admin) }
  let(:faculty) { create(:user, :faculty) }
  let(:student) { create(:user) }

  index_paths = {
    "departments" => "/admin/departments",
    "divisions" => "/admin/divisions",
    "sub_divisions" => "/admin/sub_divisions",
    "categories" => "/admin/categories",
    "reason_templates" => "/admin/reason_templates",
    "users" => "/admin/users",
    "settings" => "/admin/settings/edit"
  }

  index_paths.each do |name, path|
    describe "GET #{path}" do
      it "renders for an admin" do
        sign_in admin
        get path

        expect(response).to have_http_status(:ok)
      end

      it "redirects faculty to root with an alert" do
        sign_in faculty
        get path

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to do that.")
      end

      it "redirects a student to root with an alert" do
        sign_in student
        get path

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to do that.")
      end

      it "redirects a signed-out visitor to sign in" do
        get path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
