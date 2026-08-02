class Permission < ApplicationRecord
  ACTIONS = %w[edit_own_phone edit_own_address edit_own_photo].freeze
  ROLES = %w[student faculty].freeze

  DEFAULTS = {
    "student" => {
      "edit_own_phone" => false,
      "edit_own_address" => false,
      "edit_own_photo" => true
    },
    "faculty" => {
      "edit_own_phone" => true,
      "edit_own_address" => true,
      "edit_own_photo" => true
    }
  }.freeze

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :action, uniqueness: { scope: :role }

  def self.enabled_for?(role, action)
    return true if role.to_s == "admin"

    find_by(role: role.to_s, action: action.to_s)&.enabled? || false
  end

  def self.ensure_defaults!
    DEFAULTS.each do |role, actions|
      actions.each do |action, enabled|
        find_or_create_by!(role: role, action: action) do |permission|
          permission.enabled = enabled
        end
      end
    end
  end

  def self.grouped_by_action
    ensure_defaults!
    where(action: ACTIONS).order(:action, :role).group_by(&:action)
  end
end
