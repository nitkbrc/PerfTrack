require "rails_helper"

RSpec.describe AchievementRequest, type: :model do
  describe "proof attachments" do
    it "is valid with one PNG under 5MB" do
      request = build(:achievement_request)

      expect(request).to be_valid
    end

    it "is invalid with zero proof files" do
      request = build(:achievement_request, with_proof: false)

      expect(request).not_to be_valid
      expect(request.errors[:proofs]).to be_present
    end

    it "rejects a non-PNG file" do
      request = build(:achievement_request, with_proof: false)
      request.proofs.attach(
        io: StringIO.new("plain text pretending to be an image"),
        filename: "proof.txt",
        content_type: "text/plain"
      )

      expect(request).not_to be_valid
      expect(request.errors[:proofs]).to be_present
    end

    it "rejects a file of 5MB or more" do
      # Real PNG magic bytes followed by padding, so content type detection
      # still sees a PNG but the blob exceeds the size limit.
      png_header = Rails.root.join("spec/fixtures/files/proof.png").binread
      oversized = StringIO.new(png_header + ("\x00" * 5.megabytes))
      request = build(:achievement_request, with_proof: false)
      request.proofs.attach(io: oversized, filename: "huge.png", content_type: "image/png")

      expect(request).not_to be_valid
      expect(request.errors[:proofs]).to be_present
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
    end
  end
end
