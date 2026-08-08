require "rails_helper"

RSpec.describe "Multi-step review chain lifecycle", type: :model do
  def proof_upload
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/proof.png"), "image/png"
    )
  end

  def custom_division_role(name = "Division Reviewer")
    ReviewRole.find_or_create_by!(name: name) do |role|
      role.scope = "division"
      role.raiseable_on_behalf_eligible = false
      role.system_role = false
    end
  end

  def custom_sub_division_role(name = "Coordinator")
    ReviewRole.find_or_create_by!(name: name) do |role|
      role.scope = "sub_division"
      role.raiseable_on_behalf_eligible = false
      role.system_role = false
    end
  end

  # Builds Supervisor → Coordinator → Division Reviewer → Dean (4 assigned steps).
  def build_four_step_world
    ReviewRole.ensure_system_roles!
    Hierarchy.ensure_defaults!

    dean_user = create(:user, :faculty)
    mid_div_user = create(:user, :faculty)
    supervisor_user = create(:user, :faculty)
    coordinator_user = create(:user, :faculty)

    coordinator_role = custom_sub_division_role
    mid_div_role = custom_division_role

    div_hierarchy = Hierarchy.create!(name: "Spec Div #{SecureRandom.hex(4)}", scope: "division")
    div_hierarchy.hierarchy_roles.create!(review_role: mid_div_role, position: 1, can_raise_on_behalf: false)
    div_hierarchy.hierarchy_roles.create!(review_role: ReviewRole.dean, position: 2, can_raise_on_behalf: false)
    div_hierarchy.normalize_positions!

    sub_hierarchy = Hierarchy.create!(name: "Spec Sub #{SecureRandom.hex(4)}", scope: "sub_division")
    sub_hierarchy.hierarchy_roles.create!(review_role: ReviewRole.supervisor, position: 1, can_raise_on_behalf: true)
    sub_hierarchy.hierarchy_roles.create!(review_role: coordinator_role, position: 2, can_raise_on_behalf: false)
    sub_hierarchy.normalize_positions!

    division = create(:division, dean: dean_user)
    division.update!(hierarchy: div_hierarchy)
    RoleAssignment.create!(user: mid_div_user, review_role: mid_div_role, division: division)

    sub_division = create(:sub_division, division: division, supervisor: supervisor_user)
    sub_division.update!(hierarchy: sub_hierarchy)
    RoleAssignment.create!(user: coordinator_user, review_role: coordinator_role, sub_division: sub_division)

    category = create(:category, sub_division: sub_division, points: 30)
    student = create(:student)

    {
      dean_user: dean_user,
      mid_div_user: mid_div_user,
      supervisor_user: supervisor_user,
      coordinator_user: coordinator_user,
      coordinator_role: coordinator_role,
      mid_div_role: mid_div_role,
      division: division,
      sub_division: sub_division,
      category: category,
      student: student
    }
  end

  it "advances Path A through all four steps to final approval" do
    world = build_four_step_world
    request = AchievementRequest.submit!(
      student: world[:student],
      actor: world[:student].user,
      attrs: {
        category: world[:category],
        title: "Four-step win",
        description: "Full chain",
        proofs: [ proof_upload ]
      }
    )

    expect(request.current_review_role.name).to eq(ReviewRole::SUPERVISOR)
    expect(request.current_reviewer).to eq(world[:supervisor_user])

    request.advance!(actor: world[:supervisor_user])
    expect(request.reload.current_review_role.name).to eq("Coordinator")
    expect(request.current_reviewer).to eq(world[:coordinator_user])

    request.advance!(actor: world[:coordinator_user])
    expect(request.reload.current_review_role.name).to eq("Division Reviewer")
    expect(request.current_reviewer).to eq(world[:mid_div_user])

    request.advance!(actor: world[:mid_div_user])
    expect(request.reload.current_review_role.name).to eq(ReviewRole::DEAN)
    expect(request.current_reviewer).to eq(world[:dean_user])

    request.advance!(actor: world[:dean_user])
    expect(request.reload).to be_approved
    expect(request.points_awarded).to eq(30)
    expect(request.current_review_role_id).to be_nil
  end

  it "reverts exactly one step from Division Reviewer back to Coordinator" do
    world = build_four_step_world
    request = AchievementRequest.submit!(
      student: world[:student],
      actor: world[:student].user,
      attrs: {
        category: world[:category],
        title: "Revert mid-chain",
        description: "Clarify",
        proofs: [ proof_upload ]
      }
    )
    request.advance!(actor: world[:supervisor_user])
    request.advance!(actor: world[:coordinator_user])

    request.revert!(actor: world[:mid_div_user], comment: "Need more detail before I can advance.")

    expect(request.reload).to be_in_review
    expect(request.current_review_role.name).to eq("Coordinator")
    expect(request.current_reviewer).to eq(world[:coordinator_user])
  end

  it "rejects from a mid-chain step without awarding points" do
    world = build_four_step_world
    request = AchievementRequest.submit!(
      student: world[:student],
      actor: world[:student].user,
      attrs: {
        category: world[:category],
        title: "Reject mid-chain",
        description: "Weak evidence",
        proofs: [ proof_upload ]
      }
    )
    request.advance!(actor: world[:supervisor_user])

    request.reject!(actor: world[:coordinator_user], comment: "Insufficient evidence.")

    expect(request.reload).to be_rejected
    expect(request.points_awarded).to be_nil
  end

  it "skips an unassigned Coordinator step when resolving the live chain" do
    world = build_four_step_world
    request = AchievementRequest.submit!(
      student: world[:student],
      actor: world[:student].user,
      attrs: {
        category: world[:category],
        title: "Skip unassigned",
        description: "No coordinator",
        proofs: [ proof_upload ]
      }
    )

    RoleAssignment.where(
      review_role: world[:coordinator_role],
      sub_division: world[:sub_division]
    ).delete_all

    chain_names = ReviewChainResolver.new(request).review_chain.map { |entry| entry.review_role.name }
    expect(chain_names).to eq([
      ReviewRole::SUPERVISOR,
      "Division Reviewer",
      ReviewRole::DEAN
    ])

    request.advance!(actor: world[:supervisor_user])
    expect(request.reload.current_review_role.name).to eq("Division Reviewer")
    expect(request.current_reviewer).to eq(world[:mid_div_user])
  end

  it "Path B skips the raiseable Supervisor and lands on Coordinator" do
    world = build_four_step_world
    request = AchievementRequest.supervisor_initiate!(
      student: world[:student],
      actor: world[:supervisor_user],
      attrs: {
        category: world[:category],
        title: "Raised on behalf",
        description: "Path B into long chain",
        proofs: [ proof_upload ]
      }
    )

    expect(request).to be_in_review
    expect(request.current_review_role.name).to eq("Coordinator")
    expect(request.current_reviewer).to eq(world[:coordinator_user])
  end

  it "permits the mid division reviewer as current_reviewer via review? policy" do
    world = build_four_step_world
    request = AchievementRequest.submit!(
      student: world[:student],
      actor: world[:student].user,
      attrs: {
        category: world[:category],
        title: "Policy check",
        description: "At mid division",
        proofs: [ proof_upload ]
      }
    )
    request.advance!(actor: world[:supervisor_user])
    request.advance!(actor: world[:coordinator_user])

    expect(AchievementRequestPolicy.new(world[:mid_div_user], request).review?).to be true
    expect(AchievementRequestPolicy.new(world[:dean_user], request).review?).to be false
    expect(AchievementRequestPolicy.new(world[:supervisor_user], request).review?).to be false
  end

  it "allows a division hierarchy with only a custom role (no Dean)" do
    ReviewRole.ensure_system_roles!
    Hierarchy.ensure_defaults!
    mid_role = custom_division_role("Only Custom Div Role")
    user = create(:user, :faculty)
    hierarchy = Hierarchy.create!(name: "Custom only #{SecureRandom.hex(4)}", scope: "division")
    hierarchy.hierarchy_roles.create!(review_role: mid_role, position: 1, can_raise_on_behalf: false)

    division = create(:division)
    division.update!(hierarchy: hierarchy)
    RoleAssignment.where(division: division, review_role: ReviewRole.dean).delete_all
    RoleAssignment.create!(user: user, review_role: mid_role, division: division)

    expect(division.hierarchy.hierarchy_roles.map { |hr| hr.review_role.name }).to eq([ "Only Custom Div Role" ])
    expect(RoleAssignment.holder_for(review_role: mid_role, division: division)).to eq(user)
  end
end
