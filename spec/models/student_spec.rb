require "rails_helper"

RSpec.describe Student, type: :model do
  def proof_upload
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/proof.png"), "image/png"
    )
  end

  def approved_request(student, div_type, points)
    division = create(:division, div_type: div_type)
    sub_division = create(:sub_division, division: division)
    category = create(:category, sub_division: sub_division, points: points)
    request = AchievementRequest.submit!(
      student: student, actor: student.user,
      attrs: { category: category, title: "T", description: "D", proofs: [ proof_upload ] }
    )
    request.advance!(actor: sub_division.supervisor)
    request.advance!(actor: division.dean)
    request
  end

  describe "#positive_total and #negative_total" do
    it "sums only approved requests, split by snapshotted polarity" do
      student = create(:student)
      approved_request(student, "positive", 20)
      approved_request(student, "positive", 30)
      approved_request(student, "negative", 10)
      create(:achievement_request, student: student)

      expect(student.positive_total).to eq(50)
      expect(student.negative_total).to eq(-10)
    end

    it "returns zero for a student with no history" do
      student = create(:student)

      expect(student.positive_total).to eq(0)
      expect(student.negative_total).to eq(0)
    end

    it "keeps snapshotted polarity when a division's div_type later flips" do
      student = create(:student)
      division = create(:division, div_type: "positive")
      sub_division = create(:sub_division, division: division)
      category = create(:category, sub_division: sub_division, points: 20)
      request = AchievementRequest.submit!(
        student: student, actor: student.user,
        attrs: { category: category, title: "T", description: "D", proofs: [ proof_upload ] }
      )
      request.advance!(actor: sub_division.supervisor)
      request.advance!(actor: division.dean)

      expect(student.positive_total).to eq(20)

      division.update!(div_type: "negative")

      expect(student.reload.positive_total).to eq(20)
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

      expect(student.overall_score(k: 10)).to be > student.overall_score(k: 200)
    end
  end
end
