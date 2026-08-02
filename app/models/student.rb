class Student < ApplicationRecord
  belongs_to :user
  belongs_to :department

  has_many :achievement_requests, dependent: :destroy

  validates :usn, presence: true, uniqueness: true
  validates :sem, numericality: { only_integer: true, in: 1..8 }, allow_nil: true

  # Totals are computed on every read, never stored (TRD section 6).
  # Bucket by the snapshotted sign of points_awarded — never re-join live
  # division polarity, so later div_type edits cannot reshuffle history.
  def positive_total
    approved_points_where("points_awarded > 0")
  end

  def negative_total
    approved_points_where("points_awarded < 0")
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
    approved = AchievementRequest.approved
    positives = approved.where("points_awarded > 0").group(:student_id).sum(:points_awarded)
    negatives = approved.where("points_awarded < 0").group(:student_id).sum(:points_awarded)

    scores = Hash.new(5.0)
    (positives.keys | negatives.keys).each do |student_id|
      positive = positives[student_id].to_i
      negative = negatives[student_id].to_i
      scores[student_id] = sigmoid_score(positive - negative.abs, k)
    end
    scores
  end

  def self.sigmoid_score(net, k)
    (10 / (1 + Math.exp(-net.to_f / k))).round(1)
  end

  private

  def approved_points_where(sql_condition)
    achievement_requests.approved.where(sql_condition).sum(:points_awarded)
  end
end
