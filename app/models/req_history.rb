class ReqHistory < ApplicationRecord
  REVIEW_ACTIONS = %w[
    supervisor_initiate
    supervisor_revise
    advance
    approve
    revert
    reject
    supervisor_approve
    supervisor_reforward
    supervisor_revert
    supervisor_reject
    dean_approve
    dean_revert
    dean_reject
  ].freeze

  belongs_to :achievement_request
  belongs_to :request_version
  belongs_to :actor, class_name: "User", foreign_key: :actor_id
  belongs_to :reason_template, optional: true

  scope :review_actions, -> { where(action: REVIEW_ACTIONS) }
  scope :by_actor, ->(user) { where(actor: user) }
end
