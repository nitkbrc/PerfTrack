require "rails_helper"

RSpec.describe "Admin settings", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "shows settings hub cards that link to configuration pages" do
    get "/admin/settings/edit"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Review roles")
    expect(response.body).to include("Role assignments")
    expect(response.body).to include("Hierarchy")
    expect(response.body).to include("Role permissions")
    expect(response.body).to include("Score scale constant")
    expect(response.body).to include(admin_review_roles_path)
    expect(response.body).to include(admin_role_assignments_path)
    expect(response.body).to include(admin_hierarchies_path)
    expect(response.body).to include(role_permissions_admin_settings_path)
    expect(response.body).to include(score_scale_admin_settings_path)
  end

  it "updates score_scale_k from the score scale page" do
    student = create(:student)

    put "/admin/settings", params: { form: "score_scale", setting: { score_scale_k: 10 } }

    expect(response).to redirect_to("/admin/settings/score_scale")
    expect(Setting.instance.score_scale_k).to eq(10)
    expect(student.overall_score).to eq(5.0)
  end

  it "shows a live score curve preview on the score scale page" do
    get "/admin/settings/score_scale"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Score scale constant")
    expect(response.body).to include('data-controller="score-scale-preview"')
    expect(response.body).to include("Score curve preview")
    expect(response.body).to include("Overall score")
    expect(response.body).to include("Net points")
  end

  it "rejects an invalid k" do
    put "/admin/settings", params: { form: "score_scale", setting: { score_scale_k: 0 } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(Setting.instance.score_scale_k).to eq(50)
  end

  it "opens the role permissions page" do
    ReviewRole.ensure_system_roles!

    get "/admin/settings/role_permissions"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Role permissions")
    expect(response.body).to include("Profile self-edit")
    expect(response.body).to include("Who can add students")
    expect(response.body).to include("Students")
    expect(response.body).to include("Faculty")
    expect(response.body).to include("Phone number")
    expect(response.body).to include("Address")
    expect(response.body).to include("Profile photo")
    expect(response.body).to include(ReviewRole.dean.name)
    expect(response.body).to include(ReviewRole.supervisor.name)
    expect(response.body).to match(/Editable|Locked/)
    expect(response.body).to include("Save permissions")
  end

  it "redirects the old profile_permissions URL to role_permissions" do
    get "/admin/settings/profile_permissions"

    expect(response).to redirect_to("/admin/settings/role_permissions")
  end

  it "updates profile edit permissions" do
    Permission.ensure_defaults!
    permission = Permission.find_by!(role: "student", action: "edit_own_phone")
    expect(permission).not_to be_enabled

    put "/admin/settings", params: {
      form: "role_permissions",
      permissions: {
        permission.id.to_s => { enabled: "1" }
      }
    }

    expect(response).to redirect_to("/admin/settings/role_permissions")
    expect(permission.reload).to be_enabled
  end

  it "updates which review roles may add students" do
    ReviewRole.ensure_system_roles!
    dean = ReviewRole.dean
    expect(dean.can_create_students?).to be(false)

    put "/admin/settings", params: {
      form: "role_permissions",
      review_roles: {
        dean.id.to_s => { can_create_students: "1" }
      }
    }

    expect(response).to redirect_to("/admin/settings/role_permissions")
    expect(dean.reload.can_create_students?).to be(true)
  end

  it "accepts Rails checkbox companion values when toggling add-student permission" do
    ReviewRole.ensure_system_roles!
    dean = ReviewRole.dean
    dean.update!(can_create_students: false)

    put "/admin/settings", params: {
      form: "role_permissions",
      review_roles: {
        dean.id.to_s => { can_create_students: [ "0", "1" ] }
      }
    }

    expect(response).to redirect_to("/admin/settings/role_permissions")
    expect(dean.reload.can_create_students?).to be(true)

    put "/admin/settings", params: {
      form: "role_permissions",
      review_roles: {
        dean.id.to_s => { can_create_students: "0" }
      }
    }

    expect(dean.reload.can_create_students?).to be(false)
  end

  it "lists hierarchies for active divisions" do
    division = create(:division)

    get "/admin/hierarchies"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(division.name)
    expect(response.body).to include("Hierarchy templates")
  end
end
