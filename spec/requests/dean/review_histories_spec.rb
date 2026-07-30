require "rails_helper"

RSpec.describe "Dean review history", type: :request do
  let(:dean)         { create(:user, :faculty) }
  let(:supervisor)   { create(:user, :faculty) }
  let(:student)      { create(:student) }
  let(:division)     { create(:division, dean: dean) }
  let(:sub_division) { create(:sub_division, division: division, supervisor: supervisor) }
  let(:category)     { create(:category, sub_division: sub_division, points: 10) }
  let(:request_record) do
    create(:achievement_request, student: student, category: category, title: "Paper presentation").tap do |r|
      r.req_histories.create!(actor: student.user, action: "submit", to_status: "submitted",
                              request_version: r.current_version)
      r.update!(status: :supervisor_approved)
      r.req_histories.create!(actor: supervisor, action: "supervisor_approve",
                              from_status: "submitted", to_status: "supervisor_approved",
                              request_version: r.current_version)
    end
  end

  before { sign_in dean }

  it "moves an approved request out of the queue and into review history with a read-only timeline link" do
    patch approve_dean_achievement_request_path(request_record)
    expect(response).to redirect_to(dean_queue_path)

    history = ReqHistory.find_by!(actor: dean, action: "dean_approve")

    get dean_queue_path
    expect(response.body).not_to include("Paper presentation")

    get dean_review_histories_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("You approved")
    expect(response.body).to include("Paper presentation")
    expect(response.body).to include(dean_review_history_path(history))
    expect(response.body).not_to include(dean_achievement_request_path(request_record))

    get dean_review_history_path(history)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Timeline")
    expect(response.body).to include("Version 1")
    expect(response.body).to include("Read-only")
    expect(response.body).not_to include("Your decision")
    expect(response.body).not_to include("Approve — award points")
  end

  it "keeps the historical version title when the live request title later changes" do
    patch approve_dean_achievement_request_path(request_record)
    history = ReqHistory.find_by!(actor: dean, action: "dean_approve")

    v1 = request_record.current_version
    v2 = request_record.request_versions.build(
      version_number: 2,
      title: "Updated paper title",
      description: "Later clarification",
      category: category
    )
    v2.proofs.attach(
      io: Rails.root.join("spec/fixtures/files/proof.png").open,
      filename: "proof.png",
      content_type: "image/png"
    )
    v2.save!
    request_record.update!(title: "Updated paper title")

    get dean_review_histories_path
    expect(response.body).to include("Paper presentation")
    expect(response.body).not_to include("Updated paper title")

    get dean_review_history_path(history)
    expect(response.body).to include("Paper presentation")
    expect(response.body).to include('data-version-carousel-index-value="0"')
    expect(history.request_version_id).to eq(v1.id)
  end
end
