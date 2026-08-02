require "rails_helper"

RSpec.describe "Student dashboard", type: :request do
  let(:profile) { create(:student) }

  it "renders score, tier, integrity index and the student's own requests" do
    create(:achievement_request, student: profile, title: "My own request")
    create(:achievement_request, title: "Someone else's request")

    sign_in profile.user
    get student_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("5.0")
    # Tier is Bronze at 5.0
    expect(response.body).to include("Bronze")
    # Integrity index label present
    expect(response.body).to include("Integrity Index")
    expect(response.body).to include("Achievement Points")
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

  it "shows descriptive status labels and expandable request history" do
    supervisor = create(:user, :faculty, name: "Prof. Kavya Shetty")
    sub_division = create(:sub_division, supervisor: supervisor)
    category = create(:category, sub_division: sub_division)
    request_record = create(:achievement_request, student: profile, category: category, title: "Hackathon win",
                            at_step: :supervisor)
    submitted_at = Time.zone.local(2026, 3, 15, 10, 30)
    request_record.req_histories.create!(actor: profile.user, action: "submit", to_status: "in_review",
                                         request_version: request_record.current_version,
                                         created_at: submitted_at)
    request_record.advance!(actor: supervisor)

    sign_in profile.user
    get student_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Advanced by Prof. Kavya Shetty (Reviewer)")
    expect(response.body).to include("View history")
    expect(response.body).to include("Submitted by student")
    expect(response.body).to include("Advanced to the next reviewer")
    expect(response.body).to include("15 Mar 2026, 10:30")
  end
end
