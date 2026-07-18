require "rails_helper"

RSpec.describe "Supervisor queue", type: :request do
  let(:supervisor)   { create(:user, :faculty) }
  let(:sub_division) { create(:sub_division, supervisor: supervisor) }
  let(:category)     { create(:category, sub_division: sub_division) }

  it "shows only submitted requests under the supervisor's sub-divisions" do
    mine = create(:achievement_request, category: category, title: "In my queue")
    create(:achievement_request, title: "Another sub-division")
    approved = create(:achievement_request, category: category, title: "Already forwarded")
    approved.update!(status: :supervisor_approved)

    sign_in supervisor
    get supervisor_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("In my queue")
    expect(response.body).not_to include("Another sub-division")
    expect(response.body).not_to include("Already forwarded")
    expect(response.body).to include(mine.student.usn)
  end

  it "denies faculty without supervised sub-divisions, students, and admins" do
    [ create(:user, :faculty), create(:user), create(:user, :admin) ].each do |user|
      sign_in user
      get supervisor_root_path

      expect(response).to redirect_to(root_path)
      sign_out user
    end
  end
end
