require "rails_helper"

RSpec.describe ReviewChainResolver do
  def proof
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/proof.png"), "image/png"
    )
  end

  let(:dean) { create(:user, :faculty) }
  let(:supervisor) { create(:user, :faculty) }
  let(:division) { create(:division, dean: dean) }
  let(:sub_division) { create(:sub_division, division: division, supervisor: supervisor) }
  let(:category) { create(:category, sub_division: sub_division) }
  let(:student) { create(:student) }

  let(:request) do
    AchievementRequest.submit!(
      student: student,
      actor: student.user,
      attrs: { category: category, title: "Hackathon", description: "Won", proofs: [ proof ] }
    )
  end

  before { ReviewRole.ensure_system_roles!; Hierarchy.ensure_defaults! }

  describe "#review_chain" do
    it "returns sub-division roles then division roles with assigned users" do
      resolver = described_class.new(request)
      chain = resolver.review_chain

      expect(chain.map { |r| r.review_role.name }).to eq([ ReviewRole::SUPERVISOR, ReviewRole::DEAN ])
      expect(chain.map(&:user)).to eq([ supervisor, dean ])
    end

    it "skips roles with no RoleAssignment" do
      submitted = request # create while hierarchy is still staffed
      RoleAssignment.where(sub_division: sub_division).delete_all

      chain = described_class.new(submitted).review_chain

      expect(chain.map { |r| r.review_role.name }).to eq([ ReviewRole::DEAN ])
      expect(chain.first.user).to eq(dean)
    end

    it "resolves the same user correctly across multiple sub-divisions" do
      other_sub = create(:sub_division, division: division, supervisor: supervisor)
      other_category = create(:category, sub_division: other_sub)
      other_request = AchievementRequest.submit!(
        student: student,
        actor: student.user,
        attrs: { category: other_category, title: "Other", description: "x", proofs: [ proof ] }
      )

      first = described_class.new(request).review_chain.first
      second = described_class.new(other_request).review_chain.first

      expect(first.user).to eq(supervisor)
      expect(second.user).to eq(supervisor)
      expect(first.scope_owner).to eq(sub_division)
      expect(second.scope_owner).to eq(other_sub)
    end
  end

  describe "mid-flight hierarchy edits" do
    it "changes next_step and previous_step without mutating the request" do
      request.update_columns(current_review_role_id: ReviewRole.supervisor.id)
      original_role_id = request.current_review_role_id

      mid_user = create(:user, :faculty)
      mid_role = ReviewRole.find_or_create_by!(name: "Division Reviewer") do |role|
        role.scope = "division"
        role.raiseable_on_behalf_eligible = false
        role.system_role = false
      end

      hierarchy = Hierarchy.create!(name: "Mid-flight Div #{SecureRandom.hex(4)}", scope: "division")
      hierarchy.hierarchy_roles.create!(review_role: mid_role, position: 1, can_raise_on_behalf: false)
      hierarchy.hierarchy_roles.create!(review_role: ReviewRole.dean, position: 2, can_raise_on_behalf: false)
      hierarchy.normalize_positions!
      division.update!(hierarchy: hierarchy)
      RoleAssignment.create!(user: mid_user, review_role: mid_role, division: division)

      request.reload
      resolver = described_class.new(request)

      expect(request.current_review_role_id).to eq(original_role_id)
      expect(resolver.next_step.review_role.name).to eq("Division Reviewer")
      expect(resolver.next_step.user).to eq(mid_user)

      request.update_columns(current_review_role_id: mid_role.id)
      resolver = described_class.new(request.reload)
      expect(resolver.previous_step.user).to eq(supervisor)
      expect(resolver.next_step.user).to eq(dean)
      expect(request.current_review_role_id).to eq(mid_role.id)
    end
  end
end
