require "rails_helper"

RSpec.describe Student, type: :model do
  def approved_request(student, div_type, points)
    division = create(:division, div_type: div_type)
    sub_division = create(:sub_division, division: division)
    category = create(:category, sub_division: sub_division, points: points)
    create(:achievement_request, student: student, category: category,
           status: :supervisor_approved).tap(&:dean_approve!)
  end

  describe "#positive_total and #negative_total" do
    it "sums only dean-approved requests, split by division polarity" do
      student = create(:student)
      approved_request(student, "positive", 20)
      approved_request(student, "positive", 30)
      approved_request(student, "negative", 10)
      # Pending request in a positive division must not count.
      create(:achievement_request, student: student)

      expect(student.positive_total).to eq(50)
      expect(student.negative_total).to eq(-10)
    end

    it "returns zero for a student with no history" do
      student = create(:student)

      expect(student.positive_total).to eq(0)
      expect(student.negative_total).to eq(0)
    end
  end

  describe "#overall_score" do
    it "returns exactly 5.0 when net is zero" do
      student = create(:student)

      expect(student.overall_score).to eq(5.0)
    end

    it "returns 5.0 when positive and negative exactly balance" do
      student = create(:student)
      approved_request(student, "positive", 25)
      approved_request(student, "negative", 25)

      expect(student.overall_score).to eq(5.0)
    end

    it "scores above 5 with a positive net and below 5 with a negative net" do
      achiever = create(:student)
      approved_request(achiever, "positive", 40)

      offender = create(:student)
      approved_request(offender, "negative", 40)

      expect(achiever.overall_score).to be > 5.0
      expect(offender.overall_score).to be < 5.0
    end

    it "stays bounded between 0 and 10 for extreme nets" do
      star = create(:student)
      approved_request(star, "positive", 100_000)

      menace = create(:student)
      approved_request(menace, "negative", 100_000)

      expect(star.overall_score).to be <= 10.0
      expect(menace.overall_score).to be >= 0.0
    end

    it "respects a custom k scale constant" do
      student = create(:student)
      approved_request(student, "positive", 50)

      # Smaller k saturates faster, so the score should be higher for the same net.
      expect(student.overall_score(k: 10)).to be > student.overall_score(k: 200)
    end
  end
end
