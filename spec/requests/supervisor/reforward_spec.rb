require "rails_helper"

RSpec.describe "Supervisor re-forward after dean revert", type: :request do
  let(:supervisor)   { create(:user, :faculty) }
  let(:sub_division) { create(:sub_division, supervisor: supervisor) }
  let(:category)     { create(:category, sub_division: sub_division) }
  let(:request_record) do
    create(:achievement_request, category: category, title: "Sent back by dean")
      .tap { |r| r.update!(status: :dean_reverted) }
  end

  before { sign_in supervisor }

  it "shows dean_reverted requests in the queue" do
    request_record

    get supervisor_root_path

    expect(response.body).to include("Sent back by dean")
  end

  it "re-forwards to the dean with a supervisor_reforward history row" do
    patch approve_supervisor_achievement_request_path(request_record)

    expect(response).to redirect_to(supervisor_root_path)
    expect(request_record.reload.status).to eq("supervisor_approved")

    history = request_record.req_histories.sole
    expect(history.action).to eq("supervisor_reforward")
    expect(history.from_status).to eq("dean_reverted")
    expect(history.to_status).to eq("supervisor_approved")
  end

  context "when the student initiated the request (Path A)" do
    before do
      request_record.req_histories.create!(actor: create(:user, :student), action: "submit",
                                           to_status: "submitted", created_at: 1.hour.ago)
    end

    it "allows reverting to the student from dean_reverted" do
      patch revert_supervisor_achievement_request_path(request_record),
            params: { comment: "Please address the dean's feedback." }

      expect(response).to redirect_to(supervisor_root_path)
      expect(request_record.reload.status).to eq("supervisor_reverted")

      history = request_record.req_histories.order(:created_at).last
      expect(history.action).to eq("supervisor_revert")
      expect(history.from_status).to eq("dean_reverted")
    end

    it "does not allow the supervisor to edit the request" do
      get edit_supervisor_achievement_request_path(request_record)
      expect(response).to redirect_to(supervisor_root_path)

      patch supervisor_achievement_request_path(request_record),
            params: { achievement_request: { title: "Sneaky edit" } }

      expect(response).to redirect_to(supervisor_root_path)
      expect(flash[:alert]).to eq("Only dean-reverted requests you raised can be edited.")
      expect(request_record.reload.title).to eq("Sent back by dean")
    end
  end

  context "when the supervisor initiated the request (Path B)" do
    before do
      request_record.req_histories.create!(actor: supervisor, action: "supervisor_initiate",
                                           to_status: "supervisor_approved", created_at: 1.hour.ago)
    end

    it "does not allow reverting to the student" do
      patch revert_supervisor_achievement_request_path(request_record), params: { comment: "nope" }

      expect(response).to redirect_to(supervisor_root_path)
      expect(flash[:alert]).to eq("This request cannot be reverted to the student.")
      expect(request_record.reload.status).to eq("dean_reverted")
    end

    it "allows editing the request while dean_reverted" do
      get edit_supervisor_achievement_request_path(request_record)
      expect(response).to have_http_status(:ok)

      patch supervisor_achievement_request_path(request_record),
            params: { achievement_request: { title: "Clarified title", description: "More detail" } }

      expect(response).to redirect_to(supervisor_achievement_request_path(request_record))
      request_record.reload
      expect(request_record.title).to eq("Clarified title")
      expect(request_record.status).to eq("dean_reverted")
    end

    it "does not allow editing once the request is no longer dean_reverted" do
      request_record.update!(status: :supervisor_approved)

      patch supervisor_achievement_request_path(request_record),
            params: { achievement_request: { title: "Sneaky edit" } }

      expect(response).to redirect_to(supervisor_root_path)
      expect(request_record.reload.title).to eq("Sent back by dean")
    end
  end

  it "does not allow reject from dean_reverted" do
    patch reject_supervisor_achievement_request_path(request_record), params: { comment: "nope" }

    expect(response).to redirect_to(supervisor_root_path)
    expect(request_record.reload.status).to eq("dean_reverted")
  end
end
