require "rails_helper"

RSpec.describe SubDivision, type: :model do
  describe "dean/supervisor mutual exclusivity" do
    it "rejects a supervisor who is already a dean of a division" do
      dean = create(:user, :faculty)
      create(:division, dean: dean)

      sub_division = build(:sub_division, supervisor: dean)

      expect(sub_division).not_to be_valid
      expect(sub_division.errors[:supervisor_user_id]).to include("is already a dean of a division")
    end

    it "accepts a supervisor with no dean assignment" do
      sub_division = build(:sub_division)

      expect(sub_division).to be_valid
    end
  end
end
