class Student < ApplicationRecord
  belongs_to :user
  belongs_to :department

  has_many :achievement_requests

  validates :usn, presence: true, uniqueness: true

  # Totals are computed on every read, never stored (TRD section 6).
  def positive_total
    approved_points_in_divisions("positive")
  end

  def negative_total
    approved_points_in_divisions("negative")
  end

  # Sigmoid mapping of net points to 0..10; net = 0 scores exactly 5.0 (PRD section 5).
  def overall_score(k: 50)
    net = positive_total - negative_total.abs
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
