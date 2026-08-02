require "rails_helper"

RSpec.describe SubDivision, type: :model do
  it "creates a default Supervisor hierarchy step that can raise on behalf" do
    sub_division = create(:sub_division)
    step = sub_division.hierarchy_steps.first
    expect(step.review_role.name).to eq(ReviewRole::SUPERVISOR)
    expect(step.can_raise_on_behalf?).to eq(true)
    expect(sub_division.supervisor).to be_present
  end
end
