class ReqHistory < ApplicationRecord
  belongs_to :achievement_request
  belongs_to :actor, class_name: "User", foreign_key: :actor_id
  belongs_to :reason_template, optional: true
end
