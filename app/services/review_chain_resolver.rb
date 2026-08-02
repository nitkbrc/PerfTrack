# Resolves the live review chain for an AchievementRequest from HierarchyStep
# + RoleAssignment data. Never caches chain positions on the request — mid-flight
# hierarchy edits are reflected on the next resolve.
class ReviewChainResolver
  ResolvedStep = Data.define(:step, :user, :review_role) do
    def hierarchy_step_id = step.id
  end

  def initialize(request)
    @request = request
  end

  # Ordered [step, assigned_user] pairs: sub-division steps then division steps.
  # Steps without a RoleAssignment are skipped.
  def review_chain
    @review_chain ||= begin
      sub_division = @request.category.sub_division
      division = sub_division.division

      steps = HierarchyStep.for_sub_division(sub_division).ordered.to_a +
              HierarchyStep.for_division(division).ordered.to_a

      steps.filter_map do |step|
        user = step.assigned_user
        next if user.nil?

        ResolvedStep.new(step: step, user: user, review_role: step.review_role)
      end
    end
  end

  def current_reviewer
    return nil unless @request.current_step_id.present?

    entry = review_chain.find { |resolved| resolved.step.id == @request.current_step_id }
    entry&.user
  end

  def current_resolved_step
    return nil unless @request.current_step_id.present?

    review_chain.find { |resolved| resolved.step.id == @request.current_step_id }
  end

  def next_step
    idx = current_index
    return review_chain.first if idx.nil? && @request.current_step_id.blank?

    return nil if idx.nil?

    review_chain[idx + 1]
  end

  def previous_step
    idx = current_index
    return nil if idx.nil? || idx.zero?

    review_chain[idx - 1]
  end

  def first_step
    review_chain.first
  end

  def last_step?
    idx = current_index
    idx.present? && idx == review_chain.length - 1
  end

  # Path A: first assigned step. Path B: first step after the raiseable initiator's step.
  def entry_step_for_submit
    first_step
  end

  def entry_step_for_raise_on_behalf(actor:)
    chain = review_chain
    initiator_index = chain.index do |resolved|
      resolved.step.can_raise_on_behalf? && resolved.user.id == actor.id
    end
    return chain[initiator_index + 1] if initiator_index

    # Fallback: first raiseable step's successor, else first chain step.
    raiseable_index = chain.index { |resolved| resolved.step.can_raise_on_behalf? }
    return chain[raiseable_index + 1] if raiseable_index && chain[raiseable_index + 1]

    chain.first
  end

  private

  def current_index
    return nil if @request.current_step_id.blank?

    review_chain.index { |resolved| resolved.step.id == @request.current_step_id }
  end
end
