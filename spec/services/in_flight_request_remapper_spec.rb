require "rails_helper"

RSpec.describe InFlightRequestRemapper do
  describe ".landing_role_id" do
    it "starts at the first role when there is no overlap with passed roles" do
      landing = described_class.landing_role_id(
        old_chain_role_ids: [ 1, 2, 3 ],
        current_role_id: 2,
        new_chain_role_ids: [ 10, 11, 12 ]
      )
      expect(landing).to eq(10)
    end

    it "lands on the next role after the last passed role still on the new chain" do
      # Old a→b→c→d with a,b passed (current=c). New c→b→d → land on d.
      a, b, c, d = 1, 2, 3, 4
      landing = described_class.landing_role_id(
        old_chain_role_ids: [ a, b, c, d ],
        current_role_id: c,
        new_chain_role_ids: [ c, b, d ]
      )
      expect(landing).to eq(d)
    end

    it "lands on the last role when every new-chain role was already passed" do
      a, b, c = 1, 2, 3
      landing = described_class.landing_role_id(
        old_chain_role_ids: [ a, b, c ],
        current_role_id: c,
        new_chain_role_ids: [ a, b ]
      )
      expect(landing).to eq(b)
    end

    it "restarts at the first role when the current role is missing from the old chain" do
      landing = described_class.landing_role_id(
        old_chain_role_ids: [ 1, 2, 3 ],
        current_role_id: 99,
        new_chain_role_ids: [ 7, 8 ]
      )
      expect(landing).to eq(7)
    end

    it "raises when the new chain is empty" do
      expect {
        described_class.landing_role_id(
          old_chain_role_ids: [ 1 ],
          current_role_id: 1,
          new_chain_role_ids: []
        )
      }.to raise_error(InFlightRequestRemapper::EmptyChain)
    end
  end

  describe "#remap!" do
    def proof
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/proof.png"), "image/png"
      )
    end

    let(:admin) { create(:user, :admin) }
    let(:dean) { create(:user, :faculty) }
    let(:supervisor) { create(:user, :faculty) }
    let(:division) { create(:division, dean: dean) }
    let(:sub_division) { create(:sub_division, division: division, supervisor: supervisor) }
    let(:category) { create(:category, sub_division: sub_division) }
    let(:student) { create(:student) }
    let(:request) do
      AchievementRequest.submit!(
        student: student,
        actor: student.user,
        attrs: { category: category, title: "Remap me", description: "x", proofs: [ proof ] }
      )
    end

    before { ReviewRole.ensure_system_roles!; Hierarchy.ensure_defaults! }

    it "writes history, emails, and an in-app student notification when placement changes" do
      request
      old_ids = described_class.staffed_chain_role_ids(request)
      expect(request.current_review_role).to eq(ReviewRole.supervisor)

      # Simulate moving onto Dean only (supervisor passed / removed from path).
      remapper = described_class.new(actor: admin)

      expect {
        remapper.remap!(
          request: request,
          old_chain_role_ids: old_ids,
          new_chain_role_ids: [ ReviewRole.dean.id ]
        )
      }.to change { request.reload.current_review_role }.to(ReviewRole.dean)
        .and change { request.req_histories.where(action: "hierarchy_reassigned").count }.by(1)
        .and change { Notification.where(recipient: student.user, achievement_request: request).count }.by(1)
        .and have_enqueued_mail(RequestMailer, :hierarchy_reassigned_to_reviewer)
        .and have_enqueued_mail(RequestMailer, :hierarchy_reassigned_to_student)

      expect(request.req_histories.order(:created_at).last.comment).to include("Dean")
    end

    it "is a no-op when the chain and landing role are unchanged" do
      request
      old_ids = described_class.staffed_chain_role_ids(request)
      remapper = described_class.new(actor: admin)

      expect {
        remapper.remap!(
          request: request,
          old_chain_role_ids: old_ids,
          new_chain_role_ids: old_ids
        )
      }.not_to change { request.req_histories.count }
    end
  end
end
