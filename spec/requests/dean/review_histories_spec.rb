require "rails_helper"

RSpec.describe "Dean review history", type: :request do
  let(:dean)         { create(:user, :faculty) }
  let(:division)     { create(:division, dean: dean) }
  let(:sub_division) { create(:sub_division, division: division) }
  let(:category)     { create(:category, sub_division: sub_division, points: 10) }
  let(:request_record) do
    create(:achievement_request, category: category, title: "Paper presentation").tap do |r|
      r.update!(status: :supervisor_approved)
    end
  end

  before { sign_in dean }

  it "moves an approved request out of the queue and into review history with a timeline link" do
    patch approve_dean_achievement_request_path(request_record)
    expect(response).to redirect_to(dean_root_path)

    get dean_root_path
    expect(response.body).not_to include("Paper presentation")

    get dean_review_histories_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("You approved")
    expect(response.body).to include("Paper presentation")
    expect(response.body).to include(dean_achievement_request_path(request_record))

    get dean_achievement_request_path(request_record)
    expect(response.body).to include("Timeline")
    expect(response.body).to include("Version 1")
  end
end
