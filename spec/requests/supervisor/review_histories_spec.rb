require "rails_helper"

RSpec.describe "Supervisor review history", type: :request do
  let(:supervisor)   { create(:user, :faculty) }
  let(:sub_division) { create(:sub_division, supervisor: supervisor) }
  let(:category)     { create(:category, sub_division: sub_division) }
  let(:request_record) { create(:achievement_request, category: category, title: "Hackathon win") }

  before { sign_in supervisor }

  it "moves an approved request out of the queue and into review history with a timeline link" do
    patch approve_supervisor_achievement_request_path(request_record)
    expect(response).to redirect_to(supervisor_root_path)

    get supervisor_root_path
    expect(response.body).not_to include("Hackathon win")

    get supervisor_review_histories_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("You approved")
    expect(response.body).to include("Hackathon win")
    expect(response.body).to include(supervisor_achievement_request_path(request_record))

    get supervisor_achievement_request_path(request_record)
    expect(response.body).to include("Timeline")
    expect(response.body).to include("Version 1")
  end
end
