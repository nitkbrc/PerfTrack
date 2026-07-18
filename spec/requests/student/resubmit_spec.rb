require "rails_helper"

RSpec.describe "Student resubmit", type: :request do
  let(:profile) { create(:student) }
  let(:request_record) do
    create(:achievement_request, student: profile).tap { |r| r.update!(status: :supervisor_reverted) }
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

    history = request_record.req_histories.sole
    expect(history.action).to eq("resubmit")
    expect(history.actor).to eq(profile.user)
    expect(history.from_status).to eq("supervisor_reverted")
    expect(history.to_status).to eq("submitted")
  end

  it "adds newly uploaded proofs to the existing ones" do
    patch student_achievement_request_path(request_record), params: {
      achievement_request: { title: request_record.title, description: "desc",
                             proofs: [ fixture_file_upload("proof.png", "image/png") ] }
    }

    expect(request_record.reload.proofs.count).to eq(2)
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
