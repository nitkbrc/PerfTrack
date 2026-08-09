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

  it "renames a default hierarchy" do
    default = Hierarchy.default_for("division")
    new_name = "Renamed Default Division #{SecureRandom.hex(3)}"

    payload = {
      hierarchies: [
        {
          id: default.id,
          name: new_name,
          scope: "division",
          roles: [ { review_role_id: ReviewRole.dean.id, can_raise_on_behalf: false } ]
        }
      ],
      reattachments: [],
      deleted_hierarchy_ids: []
    }

    described_class.new(payload).call!

    expect(default.reload.name).to eq(new_name)
    expect(default).to be_is_default
  end

  describe "in-flight request remapping" do
    def proof
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/proof.png"), "image/png"
      )
    end

    let(:admin) { create(:user, :admin) }
    let(:dean_user) { create(:user, :faculty) }
    let(:supervisor_user) { create(:user, :faculty) }
    let(:mid_user) { create(:user, :faculty) }

    it "reattaches a division and remaps an in-flight request onto the new chain" do
      hierarchy, mid = build_custom_division_hierarchy
      default = Hierarchy.default_for("division")
      division = create(:division, dean: dean_user)
      division.update!(hierarchy: hierarchy)
      RoleAssignment.create!(user: mid_user, review_role: mid, division: division)
      sub_division = create(:sub_division, division: division, supervisor: supervisor_user)
      category = create(:category, sub_division: sub_division)
      student = create(:student)

      request = AchievementRequest.submit!(
        student: student,
        actor: student.user,
        attrs: { category: category, title: "Live", description: "x", proofs: [ proof ] }
      )
      # Advance past supervisor onto the custom mid division role.
      request.advance!(actor: supervisor_user)
      expect(request.reload.current_review_role).to eq(mid)

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

      expect {
        described_class.new(payload, actor: admin).call!
      }.to change { request.reload.current_review_role }.to(ReviewRole.dean)

      expect(division.reload.hierarchy).to eq(default)
      expect(request.req_histories.where(action: "hierarchy_reassigned")).to exist
      expect(Notification.where(recipient: student.user, achievement_request: request)).to exist
      expect(AchievementRequest.for_current_reviewer(dean_user)).to include(request)
      expect(AchievementRequest.for_current_reviewer(mid_user)).not_to include(request)
    end

    it "removes a role underneath an in-flight request by remapping first" do
      hierarchy, mid = build_custom_division_hierarchy
      division = create(:division, dean: dean_user)
      division.update!(hierarchy: hierarchy)
      RoleAssignment.create!(user: mid_user, review_role: mid, division: division)
      sub_division = create(:sub_division, division: division, supervisor: supervisor_user)
      category = create(:category, sub_division: sub_division)
      student = create(:student)

      request = AchievementRequest.submit!(
        student: student,
        actor: student.user,
        attrs: { category: category, title: "Live mid", description: "x", proofs: [ proof ] }
      )
      request.advance!(actor: supervisor_user)
      expect(request.reload.current_review_role).to eq(mid)

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

      expect {
        described_class.new(payload, actor: admin).call!
      }.to change { request.reload.current_review_role }.to(ReviewRole.dean)

      expect(hierarchy.reload.hierarchy_roles.map(&:review_role_id)).to eq([ ReviewRole.dean.id ])
      expect(RoleAssignment.where(division: division, review_role: mid)).to be_empty
      expect(request.req_histories.where(action: "hierarchy_reassigned")).to exist
    end

    it "aborts when an in-flight request would have no staffed landing role" do
      hierarchy, mid = build_custom_division_hierarchy
      division = create(:division, dean: dean_user)
      division.update!(hierarchy: hierarchy)
      RoleAssignment.create!(user: mid_user, review_role: mid, division: division)
      sub_division = create(:sub_division, division: division, supervisor: supervisor_user)
      category = create(:category, sub_division: sub_division)
      student = create(:student)

      request = AchievementRequest.submit!(
        student: student,
        actor: student.user,
        attrs: { category: category, title: "Stuck?", description: "x", proofs: [ proof ] }
      )
      request.advance!(actor: supervisor_user)
      expect(request.reload.current_review_role).to eq(mid)

      # Strip every assignment so the intended post-save chain has no staffed step.
      RoleAssignment.where(sub_division: sub_division).delete_all
      RoleAssignment.where(division: division).delete_all

      orphan = ReviewRole.find_or_create_by!(name: "Orphan Div Role Spec") do |role|
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
            roles: [ { review_role_id: orphan.id, can_raise_on_behalf: false } ]
          }
        ],
        reattachments: [],
        deleted_hierarchy_ids: []
      }

      expect {
        described_class.new(payload, actor: admin).call!
      }.to raise_error(HierarchyBulkSave::Error, /nowhere to land|Staff at least one role/i)

      expect(request.reload.current_review_role).to eq(mid)
      expect(hierarchy.reload.hierarchy_roles.map(&:review_role_id)).to include(mid.id)
    end
  end
end
