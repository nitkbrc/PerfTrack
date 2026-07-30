class Student < ApplicationRecord
  belongs_to :user
  belongs_to :department

  has_many :achievement_requests, dependent: :destroy

  validates :usn, presence: true, uniqueness: true
  validates :sem, numericality: { only_integer: true, in: 1..8 }, allow_nil: true

  # Totals are computed on every read, never stored (TRD section 6).
  def positive_total
    approved_points_in_divisions("positive")
  end

  def negative_total
    approved_points_in_divisions("negative")
  end

  # Sigmoid mapping of net points to 0..10; net = 0 scores exactly 5.0 (PRD section 5).
  # k defaults to the admin-configurable setting; an explicit argument still wins.
  def overall_score(k: nil)
    k ||= Setting.instance.score_scale_k
    net = positive_total - negative_total.abs
    self.class.sigmoid_score(net, k)
  end

  # Scores for every student in two queries instead of two per student —
  # used by the faculty directory listing. Students with no approved
  # requests default to 5.0 (sigmoid of net 0, regardless of k).
  def self.overall_scores(k: nil)
    k ||= Setting.instance.score_scale_k
    sums = AchievementRequest.dean_approved
                             .joins(category: { sub_division: :division })
                             .group(:student_id, "divisions.div_type")
                             .sum(:points_awarded)

    scores = Hash.new(5.0)
    sums.keys.map(&:first).uniq.each do |student_id|
      positive = sums[[ student_id, "positive" ]].to_i
      negative = sums[[ student_id, "negative" ]].to_i
      scores[student_id] = sigmoid_score(positive - negative.abs, k)
    end
    scores
  end

  def self.sigmoid_score(net, k)
    (10 / (1 + Math.exp(-net.to_f / k))).round(1)
  end

  private

  def approved_points_in_divisions(div_type)
    achievement_requests
      .dean_approved
      .joins(category: { sub_division: :division })
      .where(divisions: { div_type: div_type })
      .sum(:points_awarded)
  end
end
