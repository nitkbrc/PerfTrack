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
                                           to_status: "submitted",
                                           request_version: request_record.current_version,
                                           created_at: 1.hour.ago)
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
                                           to_status: "supervisor_approved",
                                           request_version: request_record.current_version,
                                           created_at: 1.hour.ago)
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
      expect(response.body).to include('data-controller="proof-remove"')
      expect(response.body).to include('aria-label="Remove proof"')

      expect {
        patch supervisor_achievement_request_path(request_record),
              params: { achievement_request: { title: "Clarified title", description: "More detail" } }
      }.to change { request_record.request_versions.count }.by(1)

      expect(response).to redirect_to(supervisor_achievement_request_path(request_record))
      request_record.reload
      expect(request_record.title).to eq("Clarified title")
      expect(request_record.status).to eq("dean_reverted")
      expect(request_record.request_versions.count).to eq(2)
      expect(request_record.current_version.title).to eq("Clarified title")
      expect(request_record.request_versions.find_by!(version_number: 1).title).to eq("Sent back by dean")

      history = request_record.req_histories.order(:created_at).last
      expect(history.action).to eq("supervisor_revise")
      expect(history.request_version).to eq(request_record.current_version)
    end

    it "updates the same draft on a second save without creating version 3" do
      patch supervisor_achievement_request_path(request_record),
            params: { achievement_request: { title: "Draft one", description: "a" } }
      expect {
        patch supervisor_achievement_request_path(request_record),
              params: { achievement_request: { title: "Draft two", description: "b" } }
      }.not_to change { request_record.request_versions.count }

      request_record.reload
      expect(request_record.request_versions.count).to eq(2)
      expect(request_record.title).to eq("Draft two")
      expect(request_record.current_version.version_number).to eq(2)
    end

    it "removes a saved proof immediately and keeps the prior version intact" do
      request_record.current_version.proofs.attach(
        io: Rails.root.join("spec/fixtures/files/proof.png").open,
        filename: "proof-2.png",
        content_type: "image/png"
      )
      original_version = request_record.current_version
      signed_id = original_version.proofs.first.signed_id

      expect {
        delete proof_supervisor_achievement_request_path(request_record, signed_id)
      }.to change { request_record.reload.request_versions.count }.by(1)

      expect(response).to have_http_status(:ok)
      request_record.reload
      expect(request_record.current_version.proofs.count).to eq(1)
      expect(request_record.current_version.proofs.map(&:signed_id)).not_to include(signed_id)
      expect(original_version.reload.proofs.count).to eq(2)
      expect(request_record.req_histories.where(action: "supervisor_revise").count).to eq(1)
    end

    it "rejects immediately removing the last proof" do
      delete proof_supervisor_achievement_request_path(request_record,
                                                       request_record.current_version.proofs.first.signed_id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(request_record.reload.request_versions.count).to eq(1)
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
