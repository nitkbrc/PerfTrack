# frozen_string_literal: true

class ReasonTemplateSuppression < ApplicationRecord
  belongs_to :division
  belongs_to :reason_template

  validate :template_must_be_shared

  private

  def template_must_be_shared
    return if reason_template&.shared?

    errors.add(:reason_template, "must be a shared default")
  end
end
