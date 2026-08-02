class ReviewRole < ApplicationRecord
  DEAN = "Dean"
  ASSOCIATE_DEAN = "Associate Dean"
  SUPERVISOR = "Supervisor"

  SYSTEM_DEFINITIONS = [
    { name: DEAN, scope: "division", raiseable_on_behalf_eligible: false, system_role: true },
    { name: ASSOCIATE_DEAN, scope: "division", raiseable_on_behalf_eligible: false, system_role: true },
    { name: SUPERVISOR, scope: "sub_division", raiseable_on_behalf_eligible: true, system_role: true }
  ].freeze

  has_many :hierarchy_steps, dependent: :restrict_with_exception
  has_many :role_assignments, dependent: :restrict_with_exception

  enum :scope, { division: "division", sub_division: "sub_division" }, prefix: true

  validates :name, presence: true, uniqueness: true
  validates :scope, presence: true
  validate :raiseable_only_for_sub_division_scope

  before_destroy :prevent_system_role_destroy

  def self.ensure_system_roles!
    SYSTEM_DEFINITIONS.each do |attrs|
      role = find_or_initialize_by(name: attrs[:name])
      role.assign_attributes(attrs)
      role.save!
    end
  end

  def self.dean
    ensure_system_roles!
    find_by!(name: DEAN)
  end

  def self.associate_dean
    ensure_system_roles!
    find_by!(name: ASSOCIATE_DEAN)
  end

  def self.supervisor
    ensure_system_roles!
    find_by!(name: SUPERVISOR)
  end

  private

  def raiseable_only_for_sub_division_scope
    return unless raiseable_on_behalf_eligible?
    return if scope_sub_division?

    errors.add(:raiseable_on_behalf_eligible, "is only allowed for sub-division scoped roles")
  end

  def prevent_system_role_destroy
    return unless system_role?

    errors.add(:base, "System roles cannot be deleted")
    throw :abort
  end
end
