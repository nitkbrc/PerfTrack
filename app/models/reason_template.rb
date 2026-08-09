# frozen_string_literal: true

class ReasonTemplate < ApplicationRecord
  ACTIONS = %w[revert reject].freeze

  belongs_to :division, optional: true
  has_many :req_histories, dependent: :nullify
  has_many :reason_template_suppressions, dependent: :destroy

  validates :message_text, presence: true
  validates :action, inclusion: { in: ACTIONS }

  scope :shared, -> { where(division_id: nil) }
  scope :division_extras, -> { where.not(division_id: nil) }
  scope :for_division, ->(division) { where(division_id: division.is_a?(Division) ? division.id : division) }
  scope :for_action, ->(action) { where(action: action.to_s) }
  scope :ordered, -> { order(:position, :id) }

  before_validation :assign_default_position, on: :create

  def shared?
    division_id.nil?
  end

  def revert?
    action == "revert"
  end

  def reject?
    action == "reject"
  end

  def action_label
    action.to_s.humanize
  end

  # Shared defaults (minus this division's suppressions) + division extras.
  def self.effective_for(division:, action:)
    division_id = division.is_a?(Division) ? division.id : division
    suppressed_ids = ReasonTemplateSuppression.where(division_id: division_id).select(:reason_template_id)

    shared_list = shared.for_action(action).where.not(id: suppressed_ids).ordered.to_a
    extras = for_division(division_id).for_action(action).ordered.to_a
    shared_list + extras
  end

  def self.available_to?(template_id:, division:, action:)
    effective_for(division: division, action: action).any? { |t| t.id == template_id.to_i }
  end

  private

  def assign_default_position
    return if action.blank?

    scope = self.class.where(action: action, division_id: division_id)
    max = scope.maximum(:position)
    self.position = max.nil? ? 0 : max + 1
  end
end
