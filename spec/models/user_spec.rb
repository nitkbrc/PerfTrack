require "rails_helper"

RSpec.describe User do
  describe "profile fields" do
    it "requires phone, address, and a photo" do
      user = build(:user, phone: "", address: "")
      user.photo.purge if user.photo.attached?

      expect(user).not_to be_valid
      expect(user.errors[:phone]).to include("can't be blank")
      expect(user.errors[:address]).to include("can't be blank")
      expect(user.errors[:photo]).to include("can't be blank")
    end

    it "rejects non-image photos" do
      user = build(:user)
      user.photo.attach(
        io: StringIO.new("not an image"),
        filename: "notes.txt",
        content_type: "text/plain"
      )

      expect(user).not_to be_valid
      expect(user.errors[:photo]).to be_present
    end

    it "normalizes phone to digits only" do
      user = create(:user, phone: "98765-43210")
      expect(user.phone).to eq("9876543210")
    end

    it "requires phone numbers to be unique after normalization" do
      create(:user, phone: "9876543210")
      duplicate = build(:user, phone: "98765 43210")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:phone]).to include("has already been taken")
    end

    it "allows a user to keep their own phone number" do
      user = create(:user, phone: "9111222333")
      user.name = "Updated Name"

      expect(user).to be_valid
    end
  end
end
