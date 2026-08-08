require "rails_helper"

RSpec.describe Division, type: :model do
  it "assigns the default division hierarchy and a Dean assignment" do
    division = create(:division)
    expect(division.hierarchy).to be_present
    expect(division.hierarchy.hierarchy_roles.map { |hr| hr.review_role.name }).to include(ReviewRole::DEAN)
    expect(division.dean).to be_present
    expect(division).to be_hierarchy_staffed
  end
end
