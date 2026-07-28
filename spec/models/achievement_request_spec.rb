require "rails_helper"

RSpec.describe AchievementRequest, type: :model do
  describe "#current_version" do
    it "returns the latest version by version_number" do
      request = create(:achievement_request)
      v1 = request.current_version
      v2 = create(:request_version, achievement_request: request, version_number: 2,
                                    title: "Updated", category: request.category)

      expect(request.current_version).to eq(v2)
      expect(v1.version_number).to eq(1)
    end

    it "exposes proofs on the current version" do
      request = create(:achievement_request)

      expect(request.current_version.proofs).to be_attached
    end
  end

  describe ".submit!" do
    let(:student) { create(:student) }
    let(:category) { create(:category) }
    let(:proof) do
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/proof.png"), "image/png"
      )
    end

    it "creates exactly one RequestVersion snapshotted from the submission" do
      request = described_class.submit!(
        student: student,
        actor: student.user,
        attrs: { category_id: category.id, title: "Hackathon", description: "Won", proofs: [ proof ] }
      )

      expect(request.request_versions.count).to eq(1)
      version = request.current_version
      expect(version.version_number).to eq(1)
      expect(version.title).to eq("Hackathon")
      expect(version.proofs).to be_attached
      expect(request.req_histories.sole.request_version).to eq(version)
    end
  end

  describe ".supervisor_initiate!" do
    let(:student) { create(:student) }
    let(:supervisor) { create(:user, :faculty) }
    let(:category) { create(:category) }
    let(:proof) do
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/proof.png"), "image/png"
      )
    end

    it "creates version 1 and a supervisor_initiate history in one transaction" do
      request = described_class.supervisor_initiate!(
        student: student,
        actor: supervisor,
        attrs: { category_id: category.id, title: "Conduct note", description: "Details",
                 proofs: [ proof ] }
      )

      expect(request.status).to eq("supervisor_approved")
      expect(request.request_versions.count).to eq(1)
      expect(request.current_version.version_number).to eq(1)
      expect(request.current_version.title).to eq("Conduct note")
      expect(request.current_version.proofs).to be_attached

      history = request.req_histories.sole
      expect(history.action).to eq("supervisor_initiate")
      expect(history.request_version).to eq(request.current_version)
    end
  end

  describe "#resubmit!" do
    let(:student) { create(:student) }
    let(:request_record) do
      create(:achievement_request, student: student, title: "Original").tap do |r|
        r.update!(status: :supervisor_reverted)
      end
    end

    it "creates a second version and mirrors its title onto the request" do
      request_record.resubmit!(
        actor: student.user,
        attrs: { title: "Revised title", description: "Clearer write-up" }
      )

      request_record.reload
      expect(request_record.request_versions.count).to eq(2)
      expect(request_record.current_version.version_number).to eq(2)
      expect(request_record.current_version.title).to eq("Revised title")
      expect(request_record.title).to eq("Revised title")
      expect(request_record.status).to eq("submitted")

      history = request_record.req_histories.sole
      expect(history.action).to eq("resubmit")
      expect(history.request_version).to eq(request_record.current_version)
    end
  end

  describe "#revise!" do
    let(:supervisor) { create(:user, :faculty) }
    let(:dean) { create(:user, :faculty) }
    let(:request_record) do
      create(:achievement_request, title: "Original Path B title").tap do |r|
        r.update!(status: :dean_reverted)
        r.req_histories.create!(actor: supervisor, action: "supervisor_initiate",
                                to_status: "supervisor_approved",
                                request_version: r.current_version)
      end
    end

    it "creates a second version instead of overwriting version 1" do
      request_record.revise!(
        actor: supervisor,
        attrs: { title: "Clarified after dean", description: "Fixed details" }
      )

      request_record.reload
      expect(request_record.request_versions.count).to eq(2)
      expect(request_record.request_versions.find_by!(version_number: 1).title)
        .to eq("Original Path B title")
      expect(request_record.current_version.title).to eq("Clarified after dean")
      expect(request_record.title).to eq("Clarified after dean")
      expect(request_record.status).to eq("dean_reverted")
    end

    it "coalesces further edits onto the unsent draft without creating version 3" do
      request_record.revise!(
        actor: supervisor,
        attrs: { title: "First draft save", description: "v2a" }
      )
      expect {
        request_record.revise!(
          actor: supervisor,
          attrs: { title: "Second draft save", description: "v2b" }
        )
      }.not_to change { request_record.request_versions.count }

      request_record.reload
      expect(request_record.request_versions.count).to eq(2)
      expect(request_record.current_version.version_number).to eq(2)
      expect(request_record.current_version.title).to eq("Second draft save")
      expect(request_record.request_versions.find_by!(version_number: 1).title)
        .to eq("Original Path B title")
      expect(request_record.req_histories.where(action: "supervisor_revise").count).to eq(1)
    end

    it "creates version 3 only after the draft was re-forwarded and dean-reverted again" do
      request_record.revise!(
        actor: supervisor,
        attrs: { title: "Draft for reforward", description: "ready" }
      )
      request_record.transition!(to: :supervisor_approved, actor: supervisor,
                                 action: "supervisor_reforward")
      request_record.transition!(to: :dean_reverted, actor: dean, action: "dean_revert",
                                 comment: "Still unclear")

      expect {
        request_record.revise!(
          actor: supervisor,
          attrs: { title: "Third cycle draft", description: "again" }
        )
      }.to change { request_record.request_versions.count }.from(2).to(3)

      expect(request_record.current_version.version_number).to eq(3)
      expect(request_record.current_version.title).to eq("Third cycle draft")
    end
  end

  describe "#transition!" do
    it "does not create a new version on approve/revert" do
      request = create(:achievement_request, status: :submitted)
      supervisor = create(:user, :faculty)

      expect {
        request.transition!(to: :supervisor_reverted, actor: supervisor, action: "supervisor_revert",
                            comment: "Need clearer proof")
      }.not_to change { request.request_versions.count }

      expect(request.req_histories.sole.request_version).to eq(request.current_version)
    end
  end

  describe "#dean_approve!" do
    def request_in_division(div_type, points:)
      division = create(:division, div_type: div_type)
      sub_division = create(:sub_division, division: division)
      category = create(:category, sub_division: sub_division, points: points)
      create(:achievement_request, category: category, status: :supervisor_approved)
    end

    let(:dean_user) { create(:user, :faculty) }

    it "snapshots positive points in a positive division" do
      request = request_in_division("positive", points: 20)

      request.dean_approve!(actor: dean_user)

      expect(request.reload).to be_dean_approved
      expect(request.points_awarded).to eq(20)
    end

    it "snapshots negative points in a negative division" do
      request = request_in_division("negative", points: 15)

      request.dean_approve!(actor: dean_user)

      expect(request.reload).to be_dean_approved
      expect(request.points_awarded).to eq(-15)
    end

    it "does not change points_awarded when category points are edited after approval" do
      request = request_in_division("positive", points: 20)
      request.dean_approve!(actor: dean_user)

      request.category.update!(points: 100)

      expect(request.reload.points_awarded).to eq(20)
    end

    it "writes a dean_approve history row with the actor" do
      request = request_in_division("positive", points: 20)

      request.dean_approve!(actor: dean_user)

      history = request.req_histories.sole
      expect(history.action).to eq("dean_approve")
      expect(history.actor).to eq(dean_user)
      expect(history.from_status).to eq("supervisor_approved")
      expect(history.to_status).to eq("dean_approved")
      expect(history.request_version).to eq(request.current_version)
    end
  end
end
