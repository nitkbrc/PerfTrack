# frozen_string_literal: true

# Resolves canned vs Other reason templates for revert/reject decisions.
# Faculty cannot edit canned text — the server forces the template message.
module DecisionReasons
  extend ActiveSupport::Concern

  OTHER_REASON = "other"

  private

  def load_decision_reason_templates!
    division = @achievement_request.category.sub_division.division
    @revert_reason_templates = ReasonTemplate.effective_for(division: division, action: "revert")
    @reject_reason_templates = ReasonTemplate.effective_for(division: division, action: "reject")
  end

  def resolve_decision_reason!(action:)
    division = @achievement_request.category.sub_division.division
    raw_id = params[:reason_template_id].to_s.strip

    if raw_id.blank?
      return failure_reason("Choose a reason.")
    end

    if raw_id == OTHER_REASON
      comment = params[:comment].to_s.strip
      if comment.blank?
        return failure_reason("A message is required when choosing Other.")
      end

      return success_reason(comment: comment, reason_template: nil)
    end

    template = ReasonTemplate.for_action(action).find_by(id: raw_id)
    unless template && ReasonTemplate.available_to?(template_id: template.id, division: division, action: action)
      return failure_reason("Choose a valid reason for this division.")
    end

    success_reason(comment: template.message_text, reason_template: template)
  end

  def success_reason(comment:, reason_template:)
    { ok: true, comment: comment, reason_template: reason_template }
  end

  def failure_reason(alert)
    { ok: false, alert: alert }
  end
end
