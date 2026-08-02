require "rails_helper"

RSpec.describe AchievementRequest, type: :model do
  def proof_upload
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/proof.png"), "image/png"
    )
  end

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

    it "creates exactly one RequestVersion and lands on the first chain step" do
      request = described_class.submit!(
        student: student,
        actor: student.user,
        attrs: { category_id: category.id, title: "Hackathon", description: "Won", proofs: [ proof_upload ] }
      )

      expect(request).to be_in_review
      expect(request.current_step.review_role.name).to eq(ReviewRole::SUPERVISOR)
      expect(request.request_versions.count).to eq(1)
      expect(request.req_histories.sole.request_version).to eq(request.current_version)
    end
  end

  describe ".supervisor_initiate!" do
    let(:student) { create(:student) }
    let(:supervisor) { create(:user, :faculty) }
    let(:category) { create(:category) }

    before do
      RoleAssignment.find_or_create_by!(review_role: ReviewRole.supervisor,
                                        sub_division: category.sub_division) do |a|
        a.user = supervisor
      end
    end

    it "lands on the step after the raiseable initiator" do
      request = described_class.supervisor_initiate!(
        student: student,
        actor: supervisor,
        attrs: { category_id: category.id, title: "Conduct note", description: "Details",
                 proofs: [ proof_upload ] }
      )

      expect(request).to be_in_review
      expect(request.current_step.review_role.name).to eq(ReviewRole::DEAN)
      expect(request.req_histories.sole.action).to eq("supervisor_initiate")
    end
  end

  describe "#resubmit!" do
    let(:student) { create(:student) }
    let(:request_record) do
      create(:achievement_request, student: student, title: "Original").tap do |r|
        r.req_histories.create!(actor: student.user, action: "submit", to_status: "in_review",
                                request_version: r.current_version)
        r.update!(status: :reverted, current_step: nil)
      end
    end

    it "creates a second version and returns to the first chain step" do
      request_record.resubmit!(
        actor: student.user,
        attrs: { title: "Revised title", description: "Clearer write-up" }
      )

      request_record.reload
      expect(request_record.request_versions.count).to eq(2)
      expect(request_record).to be_in_review
      expect(request_record.current_step.review_role.name).to eq(ReviewRole::SUPERVISOR)
    end
  end

  describe "#revise!" do
    let(:supervisor) { create(:user, :faculty) }
    let(:dean) { create(:user, :faculty) }
    let(:category) { create(:category) }
    let(:request_record) do
      RoleAssignment.find_or_create_by!(review_role: ReviewRole.supervisor,
                                        sub_division: category.sub_division) { |a| a.user = supervisor }
      RoleAssignment.find_or_create_by!(review_role: ReviewRole.dean,
                                        division: category.sub_division.division) { |a| a.user = dean }
      described_class.supervisor_initiate!(
        student: create(:student), actor: supervisor,
        attrs: { category: category, title: "Original Path B title", description: "x",
                 proofs: [ proof_upload ] }
      ).tap do |r|
        r.revert!(actor: dean, comment: "Clarify")
      end
    end

    it "creates a second version instead of overwriting version 1" do
      request_record.revise!(
        actor: supervisor,
        attrs: { title: "Clarified after dean", description: "Fixed details" }
      )

      request_record.reload
      expect(request_record.request_versions.count).to eq(2)
      expect(request_record.current_version.title).to eq("Clarified after dean")
      expect(request_record).to be_in_review
    end

    it "coalesces further edits onto the unsent draft without creating version 3" do
      request_record.revise!(actor: supervisor, attrs: { title: "First draft save", description: "v2a" })
      expect {
        request_record.revise!(actor: supervisor, attrs: { title: "Second draft save", description: "v2b" })
      }.not_to change { request_record.request_versions.count }

      expect(request_record.reload.current_version.title).to eq("Second draft save")
    end

    it "creates version 3 only after the draft was advanced and reverted again" do
      request_record.revise!(actor: supervisor, attrs: { title: "Draft for reforward", description: "ready" })
      request_record.advance!(actor: supervisor)
      request_record.revert!(actor: dean, comment: "Still unclear")

      expect {
        request_record.revise!(actor: supervisor, attrs: { title: "Third cycle draft", description: "again" })
      }.to change { request_record.request_versions.count }.from(2).to(3)
    end
  end

  describe "#advance! / #revert!" do
    it "does not create a new version on advance/revert" do
      student = create(:student)
      category = create(:category)
      supervisor = category.sub_division.supervisor
      request = described_class.submit!(
        student: student, actor: student.user,
        attrs: { category: category, title: "T", description: "D", proofs: [ proof_upload ] }
      )

      expect {
        request.revert!(actor: supervisor, comment: "Need clearer proof")
      }.not_to change { request.request_versions.count }

      expect(request).to be_reverted
    end
  end

  describe "#advance! final approval" do
    def request_in_division(div_type, points:)
      division = create(:division, div_type: div_type)
      sub_division = create(:sub_division, division: division)
      category = create(:category, sub_division: sub_division, points: points)
      student = create(:student)
      described_class.submit!(
        student: student, actor: student.user,
        attrs: { category: category, title: "T", description: "D", proofs: [ proof_upload ] }
      ).tap do |r|
        r.advance!(actor: sub_division.supervisor)
      end
    end

    it "snapshots positive points in a positive division" do
      request = request_in_division("positive", points: 20)
      request.advance!(actor: request.category.sub_division.division.dean)

      expect(request.reload).to be_approved
      expect(request.points_awarded).to eq(20)
    end

    it "snapshots negative points in a negative division" do
      request = request_in_division("negative", points: 15)
      request.advance!(actor: request.category.sub_division.division.dean)

      expect(request.reload).to be_approved
      expect(request.points_awarded).to eq(-15)
    end

    it "does not change points_awarded when category points are edited after approval" do
      request = request_in_division("positive", points: 20)
      request.advance!(actor: request.category.sub_division.division.dean)
      request.category.update!(points: 100)

      expect(request.reload.points_awarded).to eq(20)
    end

    it "writes an approve history row with the actor" do
      request = request_in_division("positive", points: 20)
      dean = request.category.sub_division.division.dean
      request.advance!(actor: dean)

      history = request.req_histories.order(:created_at).last
      expect(history.action).to eq("approve")
      expect(history.actor).to eq(dean)
      expect(history.to_status).to eq("approved")
    end
  end
end
