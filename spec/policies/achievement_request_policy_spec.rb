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
end
