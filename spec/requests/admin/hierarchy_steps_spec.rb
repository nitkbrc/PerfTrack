require "rails_helper"

RSpec.describe "Admin hierarchy step reordering", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:division) { create(:division) }

  before do
    sign_in admin
    ReviewRole.ensure_system_roles!
    associate = ReviewRole.associate_dean
    division.hierarchy_steps.find_or_create_by!(review_role: associate) do |step|
      step.position = 2
      step.can_raise_on_behalf = false
    end
  end

  it "moves a step down without error" do
    dean_step = division.hierarchy_steps.find_by!(review_role: ReviewRole.dean)
    associate_step = division.hierarchy_steps.find_by!(review_role: ReviewRole.associate_dean)

    patch move_down_admin_division_hierarchy_step_path(division, dean_step)

    expect(response).to redirect_to(admin_division_hierarchy_steps_path(division))
    expect(dean_step.reload.position).to eq(2)
    expect(associate_step.reload.position).to eq(1)
  end

  it "moves a step up without error" do
    associate_step = division.hierarchy_steps.find_by!(review_role: ReviewRole.associate_dean)

    patch move_up_admin_division_hierarchy_step_path(division, associate_step)

    expect(response).to redirect_to(admin_division_hierarchy_steps_path(division))
    expect(associate_step.reload.position).to eq(1)
  end

  it "bulk-applies a hierarchy without a Pundit NotDefinedError" do
    other = create(:division)

    post bulk_apply_admin_division_hierarchy_steps_path(division), params: { target_ids: [ other.id ] }

    expect(response).to redirect_to(admin_division_hierarchy_steps_path(division))
    expect(other.hierarchy_steps.ordered.map { |s| s.review_role.name })
      .to eq(division.hierarchy_steps.ordered.map { |s| s.review_role.name })
  end
end
