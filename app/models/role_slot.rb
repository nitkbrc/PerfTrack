# One review-role slot on a division or sub-division, filled or vacant.
class RoleSlot
  attr_reader :review_role, :owner, :assignment, :step

  def initialize(review_role:, owner:, assignment:, step:)
    @review_role = review_role
    @owner = owner
    @assignment = assignment
    @step = step
  end

  def vacant?
    assignment.nil?
  end

  def holder
    assignment&.user
  end
end
