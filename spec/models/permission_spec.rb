require "rails_helper"

RSpec.describe Permission, type: :model do
  before { Permission.ensure_defaults! }

  describe ".enabled_for?" do
    it "always allows admin" do
      expect(Permission.enabled_for?("admin", "edit_own_phone")).to eq(true)
    end

    it "uses seeded defaults for students and faculty" do
      expect(Permission.enabled_for?("student", "edit_own_phone")).to eq(false)
      expect(Permission.enabled_for?("student", "edit_own_photo")).to eq(true)
      expect(Permission.enabled_for?("faculty", "edit_own_address")).to eq(true)
    end
  end
end
