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
end
