require "rails_helper"

RSpec.describe "Student resubmit", type: :request do
  let(:profile) { create(:student) }
  let(:request_record) do
    create(:achievement_request, student: profile).tap do |r|
      r.req_histories.create!(actor: profile.user, action: "submit",
                              to_status: "submitted", request_version: r.current_version)
      r.update!(status: :supervisor_reverted)
    end
  end

  before { sign_in profile.user }

  it "updates the request and returns it to submitted with a resubmit history row" do
    patch student_achievement_request_path(request_record), params: {
      achievement_request: { title: "Fixed title", description: "Now with clearer proof" }
    }

    expect(response).to redirect_to(student_achievement_request_path(request_record))
    request_record.reload
    expect(request_record.status).to eq("submitted")
    expect(request_record.title).to eq("Fixed title")
    expect(request_record.request_versions.count).to eq(2)
    expect(request_record.title).to eq(request_record.current_version.title)

    history = request_record.req_histories.order(:created_at).last
    expect(history.action).to eq("resubmit")
    expect(history.actor).to eq(profile.user)
    expect(history.from_status).to eq("supervisor_reverted")
    expect(history.to_status).to eq("submitted")
    expect(history.request_version).to eq(request_record.current_version)
  end

  it "adds newly uploaded proofs to the existing ones" do
    patch student_achievement_request_path(request_record), params: {
      achievement_request: { title: request_record.title, description: "desc",
                             proofs: [ fixture_file_upload("proof.png", "image/png") ] }
    }

    expect(request_record.reload.current_version.proofs.count).to eq(2)
  end

  it "shows the immediate remove control on the edit page" do
    get edit_student_achievement_request_path(request_record)

    expect(response.body).to include('data-controller="proof-remove"')
    expect(response.body).to include('aria-label="Remove proof"')
  end

  it "removes a saved proof immediately by creating a draft version first" do
    request_record.current_version.proofs.attach(
      io: Rails.root.join("spec/fixtures/files/proof.png").open,
      filename: "proof-2.png",
      content_type: "image/png"
    )
    original_version = request_record.current_version
    signed_id = original_version.proofs.first.signed_id

    expect {
      delete proof_student_achievement_request_path(request_record, signed_id)
    }.to change { request_record.reload.request_versions.count }.by(1)

    expect(response).to have_http_status(:ok)
    request_record.reload
    expect(request_record.status).to eq("supervisor_reverted")
    expect(request_record.current_version.proofs.count).to eq(1)
    expect(request_record.current_version.proofs.map(&:signed_id)).not_to include(signed_id)
    expect(original_version.reload.proofs.count).to eq(2)
  end

  it "resubmits using the same draft after immediate remove instead of creating version 3" do
    request_record.current_version.proofs.attach(
      io: Rails.root.join("spec/fixtures/files/proof.png").open,
      filename: "proof-2.png",
      content_type: "image/png"
    )
    delete proof_student_achievement_request_path(request_record,
                                                  request_record.current_version.proofs.first.signed_id)

    expect {
      patch student_achievement_request_path(request_record), params: {
        achievement_request: { title: "Fixed title", description: "Now with clearer proof" }
      }
    }.not_to change { request_record.reload.request_versions.count }

    expect(response).to redirect_to(student_achievement_request_path(request_record))
    expect(request_record.reload.current_version.version_number).to eq(2)
  end

  it "rejects immediately removing the last proof" do
    original = request_record.current_version.proofs.first
    delete proof_student_achievement_request_path(request_record, original.signed_id)

    expect(response).to have_http_status(:unprocessable_content)
    expect(request_record.reload.request_versions.count).to eq(1)
  end

  it "is blocked for non-reverted requests" do
    submitted = create(:achievement_request, student: profile)

    patch student_achievement_request_path(submitted), params: {
      achievement_request: { title: "Sneaky edit", description: "x" }
    }

    expect(response).to redirect_to(root_path)
    expect(submitted.reload.title).not_to eq("Sneaky edit")
  end

  it "is blocked for another student's reverted request" do
    other = create(:achievement_request).tap { |r| r.update!(status: :supervisor_reverted) }

    get edit_student_achievement_request_path(other)

    expect(response).to redirect_to(root_path)
  end
end
