require "rails_helper"

RSpec.describe "Student dashboard", type: :request do
  let(:profile) { create(:student) }

  it "renders score and the student's own requests" do
    create(:achievement_request, student: profile, title: "My own request")
    create(:achievement_request, title: "Someone else's request")

    sign_in profile.user
    get student_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("5.0")
    expect(response.body).to include("My own request")
    expect(response.body).not_to include("Someone else&#39;s request")
  end

  it "redirects faculty and admin to root" do
    [ create(:user, :faculty), create(:user, :admin) ].each do |user|
      sign_in user
      get student_root_path

      expect(response).to redirect_to(root_path)
      sign_out user
    end
  end

  it "redirects a student-role user without a profile" do
    sign_in create(:user)
    get student_root_path

    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to eq("You are not authorized to do that.")
  end

  it "redirects a signed-out visitor to sign in" do
    get student_root_path

    expect(response).to redirect_to(new_user_session_path)
  end
end
