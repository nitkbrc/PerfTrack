require "rails_helper"

RSpec.describe AchievementRequestPolicy do
  # One division with one sub-division; the request lives under that sub-division.
  let(:dean)         { create(:user, :faculty) }
  let(:supervisor)   { create(:user, :faculty) }
  let(:other_faculty) { create(:user, :faculty) }
  let(:student_user) { create(:user) }
  let(:admin)        { create(:user, :admin) }

  let(:division)     { create(:division, dean: dean) }
  let(:sub_division) { create(:sub_division, division: division, supervisor: supervisor) }
  let(:category)     { create(:category, sub_division: sub_division) }
  let(:request)      { create(:achievement_request, category: category) }

  describe "#review?" do
    it "permits the sub-division's assigned supervisor" do
      expect(described_class.new(supervisor, request).review?).to be true
    end

    it "denies faculty not assigned to the sub-division" do
      expect(described_class.new(other_faculty, request).review?).to be false
    end

    it "denies the division's dean" do
      expect(described_class.new(dean, request).review?).to be false
    end

    it "denies a student" do
      expect(described_class.new(student_user, request).review?).to be false
    end

    it "denies an admin" do
      expect(described_class.new(admin, request).review?).to be false
    end

    it "denies a supervisor of a different sub-division" do
      other_sub = create(:sub_division, division: division)

      expect(described_class.new(other_sub.supervisor, request).review?).to be false
    end
  end

  describe "#dean_decide?" do
    it "permits the division's dean" do
      expect(described_class.new(dean, request).dean_decide?).to be true
    end

    it "denies the sub-division's supervisor" do
      expect(described_class.new(supervisor, request).dean_decide?).to be false
    end

    it "denies faculty not deaning the division" do
      expect(described_class.new(other_faculty, request).dean_decide?).to be false
    end

    it "denies a student" do
      expect(described_class.new(student_user, request).dean_decide?).to be false
    end

    it "denies an admin" do
      expect(described_class.new(admin, request).dean_decide?).to be false
    end

    it "denies the dean of a different division" do
      other_division = create(:division)

      expect(described_class.new(other_division.dean, request).dean_decide?).to be false
    end
  end

  describe "student submission actions" do
    let(:profile)      { create(:student) }
    let(:owner)        { profile.user }
    let(:own_request)  { create(:achievement_request, student: profile, category: category) }

    %i[index? new? create?].each do |action|
      describe "##{action}" do
        it "permits a student with a profile" do
          expect(described_class.new(owner, AchievementRequest).public_send(action)).to be true
        end

        it "denies a student without a profile" do
          expect(described_class.new(student_user, AchievementRequest).public_send(action)).to be false
        end

        it "denies faculty and admin" do
          expect(described_class.new(other_faculty, AchievementRequest).public_send(action)).to be false
          expect(described_class.new(admin, AchievementRequest).public_send(action)).to be false
        end
      end
    end

    describe "#show?" do
      it "permits the owning student" do
        expect(described_class.new(owner, own_request).show?).to be true
      end

      it "denies a different student" do
        other = create(:student)

        expect(described_class.new(other.user, own_request).show?).to be false
      end
    end
  end

  describe "Scope" do
    it "resolves to the student's own requests only" do
      profile = create(:student)
      own = create(:achievement_request, student: profile, category: category)
      create(:achievement_request, category: category)

      resolved = described_class::Scope.new(profile.user, AchievementRequest).resolve
      expect(resolved).to contain_exactly(own)
    end

    it "resolves to none for faculty, admin, and profile-less students" do
      create(:achievement_request, category: category)

      [ other_faculty, admin, student_user ].each do |u|
        expect(described_class::Scope.new(u, AchievementRequest).resolve).to be_empty
      end
    end
  end
end
