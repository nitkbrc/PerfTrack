class Setting < ApplicationRecord
  validates :score_scale_k, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # Single-row settings table.
  def self.instance
    first_or_create!
  end
end
