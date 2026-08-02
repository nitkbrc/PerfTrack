require "rails_helper"

RSpec.describe Division, type: :model do
  it "creates a default Dean hierarchy step" do
    division = create(:division)
    expect(division.hierarchy_steps.count).to eq(1)
    expect(division.hierarchy_steps.first.review_role.name).to eq(ReviewRole::DEAN)
    expect(division.dean).to be_present
  end
end
