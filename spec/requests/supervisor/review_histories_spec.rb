require "rails_helper"

RSpec.describe "Supervisor review history", type: :request do
  let(:supervisor)   { create(:user, :faculty) }
  let(:dean)         { create(:user, :faculty) }
  let(:student)      { create(:student) }
  let(:division)     { create(:division, dean: dean) }
  let(:sub_division) { create(:sub_division, division: division, supervisor: supervisor) }
  let(:category)     { create(:category, sub_division: sub_division) }
  let(:request_record) do
    create(:achievement_request, student: student, category: category, title: "Hackathon win").tap do |r|
      r.req_histories.create!(actor: student.user, action: "submit", to_status: "submitted",
                              request_version: r.current_version)
    end
  end

  before { sign_in supervisor }

  it "moves an approved request out of the queue and into review history with a read-only timeline link" do
    patch approve_supervisor_achievement_request_path(request_record)
    expect(response).to redirect_to(supervisor_queue_path)

    history = ReqHistory.find_by!(actor: supervisor, action: "supervisor_approve")

    get supervisor_queue_path
    expect(response.body).not_to include("Hackathon win")

    get supervisor_review_histories_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("You approved")
    expect(response.body).to include("Hackathon win")
    expect(response.body).to include(supervisor_review_history_path(history))
    expect(response.body).not_to include(supervisor_achievement_request_path(request_record))

    get supervisor_review_history_path(history)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Timeline")
    expect(response.body).to include("Version 1")
    expect(response.body).to include("Hackathon win")
    expect(response.body).to include("Read-only")
    expect(response.body).not_to include("Your decision")
    expect(response.body).not_to include("Approve & forward to dean")
    expect(response.body).not_to include("Re-forward to dean")
  end

  it "keeps the historical version title after a later resubmit" do
    patch approve_supervisor_achievement_request_path(request_record)
    history = ReqHistory.find_by!(actor: supervisor, action: "supervisor_approve")

    request_record.transition!(to: :dean_reverted, actor: dean, action: "dean_revert",
                               comment: "Need clearer dates")
    request_record.transition!(to: :supervisor_reverted, actor: supervisor,
                               action: "supervisor_revert", comment: "Please revise")
    request_record.resubmit!(actor: student.user,
                             attrs: { title: "Revised hackathon write-up",
                                      description: "Added dates" })
    request_record.reload
    expect(request_record.title).to eq("Revised hackathon write-up")

    get supervisor_review_histories_path
    expect(response.body).to include("Hackathon win")
    # Approve row still uses version 1 title; revised title may also appear on a
    # later history row, so assert the approve entry path still opens v1.
    get supervisor_review_history_path(history)
    expect(response.body).to include("Hackathon win")
    expect(response.body).to include('data-version-carousel-index-value="0"')
    expect(response.body).not_to include("Your decision")
  end
end
