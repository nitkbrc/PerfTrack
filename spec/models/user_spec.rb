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

  describe "#can_create_students?" do
    it "is true for admins" do
      expect(build(:user, :admin).can_create_students?).to be(true)
    end

    it "is false for unassigned faculty even when a review role is enabled" do
      ReviewRole.ensure_system_roles!
      ReviewRole.dean.update!(can_create_students: true)
      faculty = create(:user, :faculty)

      expect(faculty.can_create_students?).to be(false)
    end

    it "is true for faculty who hold an enabled review role assignment" do
      ReviewRole.ensure_system_roles!
      ReviewRole.dean.update!(can_create_students: true)
      faculty = create(:user, :faculty)
      create(:division, dean: faculty)

      expect(faculty.can_create_students?).to be(true)
    end

    it "is false for faculty whose review role is not enabled" do
      ReviewRole.ensure_system_roles!
      ReviewRole.dean.update!(can_create_students: false)
      faculty = create(:user, :faculty)
      create(:division, dean: faculty)

      expect(faculty.can_create_students?).to be(false)
    end

    it "is false for students" do
      expect(create(:student).user.can_create_students?).to be(false)
    end
  end
end
