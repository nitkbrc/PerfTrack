require "rails_helper"

RSpec.describe SubDivision, type: :model do
  it "assigns the default sub-division hierarchy with raiseable Supervisor" do
    sub_division = create(:sub_division)
    expect(sub_division.hierarchy).to be_present
    expect(sub_division.hierarchy.hierarchy_roles.first.review_role.name).to eq(ReviewRole::SUPERVISOR)
    expect(sub_division.effective_can_raise_on_behalf?(ReviewRole.supervisor)).to eq(true)
    expect(sub_division.supervisor).to be_present
    expect(sub_division).to be_hierarchy_staffed
  end

  it "rejects clearing the hierarchy" do
    sub_division = create(:sub_division)
    sub_division.hierarchy = nil

    expect(sub_division).not_to be_valid
    expect(sub_division.errors[:hierarchy]).to be_present
  end
end
