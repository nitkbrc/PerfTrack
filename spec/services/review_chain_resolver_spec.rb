require "rails_helper"

RSpec.describe ReviewChainResolver do
  def proof
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/proof.png"), "image/png"
    )
  end

  let(:dean) { create(:user, :faculty) }
  let(:supervisor) { create(:user, :faculty) }
  let(:other_supervisor) { create(:user, :faculty) }
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

  before { ReviewRole.ensure_system_roles! }

  describe "#review_chain" do
    it "returns sub-division steps then division steps with assigned users" do
      resolver = described_class.new(request)
      chain = resolver.review_chain

      expect(chain.map { |r| r.review_role.name }).to eq([ ReviewRole::SUPERVISOR, ReviewRole::DEAN ])
      expect(chain.map(&:user)).to eq([ supervisor, dean ])
    end

    it "skips steps with no RoleAssignment" do
      RoleAssignment.where(sub_division: sub_division).delete_all

      chain = described_class.new(request).review_chain

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
      expect(first.step.sub_division_id).to eq(sub_division.id)
      expect(second.step.sub_division_id).to eq(other_sub.id)
    end
  end

  describe "mid-flight hierarchy edits" do
    it "changes next_step and previous_step without mutating the request" do
      supervisor_step = sub_division.hierarchy_steps.ordered.first
      request.update_columns(current_step_id: supervisor_step.id)
      original_step_id = request.current_step_id

      associate = create(:user, :faculty)
      associate_role = ReviewRole.associate_dean
      # Shift dean to position 2 first to free position 1
      dean_step = division.hierarchy_steps.find_by!(review_role: ReviewRole.dean)
      dean_step.update!(position: 2)
      insert = HierarchyStep.create!(
        review_role: associate_role,
        division: division,
        position: 1
      )
      RoleAssignment.create!(user: associate, review_role: associate_role, division: division)

      request.reload
      resolver = described_class.new(request)

      expect(request.current_step_id).to eq(original_step_id)
      expect(resolver.next_step.review_role.name).to eq(ReviewRole::ASSOCIATE_DEAN)
      expect(resolver.next_step.user).to eq(associate)

      request.update_columns(current_step_id: insert.id)
      resolver = described_class.new(request.reload)
      expect(resolver.previous_step.user).to eq(supervisor)
      expect(resolver.next_step.user).to eq(dean)
      expect(request.current_step_id).to eq(insert.id)
    end
  end
end
