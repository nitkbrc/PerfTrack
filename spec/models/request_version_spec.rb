require "rails_helper"

RSpec.describe RequestVersion, type: :model do
  describe "proof attachments" do
    it "is valid with one PNG under 5MB" do
      version = build(:request_version)

      expect(version).to be_valid
    end

    it "is invalid with zero proof files" do
      version = build(:request_version, with_proof: false)

      expect(version).not_to be_valid
      expect(version.errors[:proofs]).to be_present
    end

    it "rejects a non-PNG file" do
      version = build(:request_version, with_proof: false)
      version.proofs.attach(
        io: StringIO.new("plain text pretending to be an image"),
        filename: "proof.txt",
        content_type: "text/plain"
      )

      expect(version).not_to be_valid
      expect(version.errors[:proofs]).to be_present
    end

    it "rejects a file of 5MB or more" do
      # Real PNG magic bytes followed by padding, so content type detection
      # still sees a PNG but the blob exceeds the size limit.
      png_header = Rails.root.join("spec/fixtures/files/proof.png").binread
      oversized = StringIO.new(png_header + ("\x00" * 5.megabytes))
      version = build(:request_version, with_proof: false)
      version.proofs.attach(io: oversized, filename: "huge.png", content_type: "image/png")

      expect(version).not_to be_valid
      expect(version.errors[:proofs]).to be_present
    end
  end
end
