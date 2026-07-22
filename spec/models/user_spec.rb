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
  end
end
