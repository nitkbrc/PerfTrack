require "rails_helper"

RSpec.describe "Admin hierarchy step reordering", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:division) { create(:division) }
  let(:mid_role) do
    ReviewRole.find_or_create_by!(name: "Division Reviewer") do |role|
      role.scope = "division"
      role.raiseable_on_behalf_eligible = false
      role.system_role = false
    end
  end

  before do
    sign_in admin
    ReviewRole.ensure_system_roles!
    HierarchyStep.create!(
      review_role: mid_role,
      division: division,
      position: (division.hierarchy_steps.maximum(:position) || 0) + 1
    )
    HierarchyStep.normalize_positions_for!(division)
  end

  it "moves a mid step down without error and keeps Dean last" do
    mid_step = division.hierarchy_steps.find_by!(review_role: mid_role)
    dean_step = division.hierarchy_steps.find_by!(review_role: ReviewRole.dean)

    patch move_down_admin_division_hierarchy_step_path(division, mid_step)

    expect(response).to redirect_to(admin_division_hierarchy_steps_path(division))
    expect(mid_step.reload.position).to be < dean_step.reload.position
    expect(dean_step.position).to eq(division.hierarchy_steps.maximum(:position))
  end

  it "moves a mid step up without error and keeps Dean last" do
    mid_step = division.hierarchy_steps.find_by!(review_role: mid_role)

    patch move_up_admin_division_hierarchy_step_path(division, mid_step)

    expect(response).to redirect_to(admin_division_hierarchy_steps_path(division))
    expect(division.hierarchy_steps.find_by!(review_role: ReviewRole.dean).position)
      .to eq(division.hierarchy_steps.maximum(:position))
  end

  it "refuses to remove the last remaining step" do
    mid_step = division.hierarchy_steps.find_by!(review_role: mid_role)
    mid_step.destroy!
    HierarchyStep.normalize_positions_for!(division)
    dean_step = division.hierarchy_steps.find_by!(review_role: ReviewRole.dean)

    delete admin_division_hierarchy_step_path(division, dean_step)

    expect(response).to redirect_to(admin_division_hierarchy_steps_path(division))
    expect(flash[:alert]).to match(/last review step/i)
    expect(dean_step.reload).to be_persisted
  end

  it "bulk-applies a hierarchy without a Pundit NotDefinedError" do
    other = create(:division)

    post bulk_apply_admin_division_hierarchy_steps_path(division), params: { target_ids: [ other.id ] }

    expect(response).to redirect_to(admin_division_hierarchy_steps_path(division))
    expect(other.hierarchy_steps.ordered.map { |s| s.review_role.name })
      .to eq(division.hierarchy_steps.ordered.map { |s| s.review_role.name })
  end
end
