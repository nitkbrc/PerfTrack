require "rails_helper"

RSpec.describe HierarchyStep, type: :model do
  before { ReviewRole.ensure_system_roles! }

  describe ".normalize_positions_for!" do
    it "keeps Supervisor first and Dean last when both chains are present" do
      division = create(:division)
      mid_role = ReviewRole.find_or_create_by!(name: "Division Reviewer") do |r|
        r.scope = "division"
        r.raiseable_on_behalf_eligible = false
        r.system_role = false
      end
      HierarchyStep.create!(
        review_role: mid_role,
        division: division,
        position: (division.hierarchy_steps.maximum(:position) || 0) + 1
      )
      described_class.normalize_positions_for!(division)

      names = division.hierarchy_steps.ordered.map { |s| s.review_role.name }
      expect(names.last).to eq(ReviewRole::DEAN)
      expect(names).to include("Division Reviewer")

      sub = create(:sub_division, division: division)
      coord = ReviewRole.find_or_create_by!(name: "Coordinator") do |r|
        r.scope = "sub_division"
        r.raiseable_on_behalf_eligible = false
        r.system_role = false
      end
      HierarchyStep.create!(
        review_role: coord,
        sub_division: sub,
        position: (sub.hierarchy_steps.maximum(:position) || 0) + 1
      )
      described_class.normalize_positions_for!(sub)

      sub_names = sub.hierarchy_steps.ordered.map { |s| s.review_role.name }
      expect(sub_names.first).to eq(ReviewRole::SUPERVISOR)
    end
  end

  describe "last-step guard" do
    it "blocks destroying the only step on a division" do
      division = create(:division)
      step = division.hierarchy_steps.sole

      expect(step.destroy).to be false
      expect(step.errors[:base].join).to match(/last review step/i)
      expect(division.hierarchy_steps.reload).to contain_exactly(step)
    end
  end

  describe "ReviewRole system set" do
    it "does not treat Associate Dean as a system role" do
      ReviewRole.ensure_system_roles!
      role = ReviewRole.find_or_create_by!(name: ReviewRole::ASSOCIATE_DEAN) do |r|
        r.scope = "division"
        r.raiseable_on_behalf_eligible = false
        r.system_role = false
      end
      role.update!(system_role: false)

      expect(role).not_to be_system_role
      expect(ReviewRole::SYSTEM_DEFINITIONS.map { |d| d[:name] }).not_to include(ReviewRole::ASSOCIATE_DEAN)
      role_id = role.id
      expect(role.destroy).to be_truthy
      expect(ReviewRole.find_by(id: role_id)).to be_nil
    end
  end
end
