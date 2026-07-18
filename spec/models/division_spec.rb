require "rails_helper"

RSpec.describe Division, type: :model do
  describe "dean/supervisor mutual exclusivity" do
    it "rejects a dean who is already a supervisor of a sub-division" do
      supervisor = create(:user, :faculty)
      create(:sub_division, supervisor: supervisor)

      division = build(:division, dean: supervisor)

      expect(division).not_to be_valid
      expect(division.errors[:dean_user_id]).to include("is already a supervisor of a sub-division")
    end

    it "accepts a dean with no supervisor assignment" do
      division = build(:division)

      expect(division).to be_valid
    end
  end
end
