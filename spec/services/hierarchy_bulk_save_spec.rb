require "rails_helper"

RSpec.describe HierarchyBulkSave do
  before do
    ReviewRole.ensure_system_roles!
    Hierarchy.ensure_defaults!
  end

  def build_custom_division_hierarchy
    mid = ReviewRole.find_or_create_by!(name: "Division Reviewer Spec") do |role|
      role.scope = "division"
      role.system_role = false
      role.raiseable_on_behalf_eligible = false
    end

    hierarchy = Hierarchy.create!(
      name: "Bulk Save Spec #{SecureRandom.hex(4)}",
      scope: "division",
      is_default: false
    )
    hierarchy.hierarchy_roles.create!(review_role: mid, position: 1, can_raise_on_behalf: false)
    hierarchy.hierarchy_roles.create!(review_role: ReviewRole.dean, position: 2, can_raise_on_behalf: false)
    hierarchy.normalize_positions!
    [ hierarchy, mid ]
  end

  it "reorders roles without position uniqueness or validation errors" do
    hierarchy, mid = build_custom_division_hierarchy

    # Requested order puts Dean first in payload; normalize should still pin Dean last.
    payload = {
      hierarchies: [
        {
          id: hierarchy.id,
          name: hierarchy.name,
          scope: "division",
          roles: [
            { review_role_id: ReviewRole.dean.id, can_raise_on_behalf: false },
            { review_role_id: mid.id, can_raise_on_behalf: false }
          ]
        }
      ],
      reattachments: [],
      deleted_hierarchy_ids: []
    }

    expect { described_class.new(payload).call! }.not_to raise_error

    names = hierarchy.reload.hierarchy_roles.ordered.map { |hr| hr.review_role.name }
    expect(names).to eq([ "Division Reviewer Spec", ReviewRole::DEAN ])
  end

  it "reattaches a division and drops obsolete role assignments" do
    hierarchy, mid = build_custom_division_hierarchy
    default = Hierarchy.default_for("division")
    dean_user = create(:user, :faculty)
    mid_user = create(:user, :faculty)
    division = create(:division, dean: dean_user)
    division.update!(hierarchy: hierarchy)
    RoleAssignment.create!(user: mid_user, review_role: mid, division: division)

    payload = {
      hierarchies: [
        {
          id: default.id,
          name: default.name,
          scope: "division",
          roles: [ { review_role_id: ReviewRole.dean.id, can_raise_on_behalf: false } ]
        },
        {
          id: hierarchy.id,
          name: hierarchy.name,
          scope: "division",
          roles: [
            { review_role_id: mid.id, can_raise_on_behalf: false },
            { review_role_id: ReviewRole.dean.id, can_raise_on_behalf: false }
          ]
        }
      ],
      reattachments: [
        { owner_type: "Division", owner_id: division.id, hierarchy_id: default.id }
      ],
      deleted_hierarchy_ids: []
    }

    described_class.new(payload).call!

    expect(division.reload.hierarchy).to eq(default)
    expect(RoleAssignment.where(division: division, review_role: mid)).to be_empty
    expect(RoleAssignment.where(division: division, review_role: ReviewRole.dean)).to exist
  end

  it "can replace every role without tripping the last-role guard" do
    hierarchy, mid = build_custom_division_hierarchy
    replacement = ReviewRole.find_or_create_by!(name: "Division Replacement Spec") do |role|
      role.scope = "division"
      role.system_role = false
      role.raiseable_on_behalf_eligible = false
    end

    payload = {
      hierarchies: [
        {
          id: hierarchy.id,
          name: hierarchy.name,
          scope: "division",
          roles: [
            { review_role_id: replacement.id, can_raise_on_behalf: false },
            { review_role_id: ReviewRole.dean.id, can_raise_on_behalf: false }
          ]
        }
      ],
      reattachments: [],
      deleted_hierarchy_ids: []
    }

    expect { described_class.new(payload).call! }.not_to raise_error
    names = hierarchy.reload.hierarchy_roles.ordered.map { |hr| hr.review_role.name }
    expect(names).to eq([ "Division Replacement Spec", ReviewRole::DEAN ])
    expect(hierarchy.hierarchy_roles.where(review_role: mid)).to be_empty
  end

  it "removes role assignments when a role is dropped from a template" do
    hierarchy, mid = build_custom_division_hierarchy
    dean_user = create(:user, :faculty)
    mid_user = create(:user, :faculty)
    division = create(:division, dean: dean_user)
    division.update!(hierarchy: hierarchy)
    RoleAssignment.create!(user: mid_user, review_role: mid, division: division)

    payload = {
      hierarchies: [
        {
          id: hierarchy.id,
          name: hierarchy.name,
          scope: "division",
          roles: [ { review_role_id: ReviewRole.dean.id, can_raise_on_behalf: false } ]
        }
      ],
      reattachments: [],
      deleted_hierarchy_ids: []
    }

    described_class.new(payload).call!

    expect(hierarchy.reload.hierarchy_roles.map(&:review_role_id)).to eq([ ReviewRole.dean.id ])
    expect(RoleAssignment.where(division: division, review_role: mid)).to be_empty
    expect(RoleAssignment.where(division: division, review_role: ReviewRole.dean)).to exist
  end
end
