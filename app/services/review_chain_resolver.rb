# Resolves the live review chain for an AchievementRequest from shared Hierarchy
# templates + RoleAssignment data. Never caches chain positions on the request —
# mid-flight hierarchy edits are reflected on the next resolve.
class ReviewChainResolver
  ResolvedStep = Data.define(:hierarchy_role, :user, :review_role, :can_raise_on_behalf, :scope_owner) do
    def can_raise_on_behalf? = can_raise_on_behalf
    def review_role_id = review_role.id
  end

  def initialize(request)
    @request = request
  end

  # Ordered assigned roles: sub-division hierarchy then division hierarchy.
  # Unstaffed roles are skipped.
  def review_chain
    @review_chain ||= begin
      sub_division = @request.category.sub_division
      division = sub_division.division

      sub_roles = hierarchy_roles_for(sub_division)
      div_roles = hierarchy_roles_for(division)

      (sub_roles + div_roles).filter_map do |hierarchy_role|
        owner = hierarchy_role.hierarchy.scope_sub_division? ? sub_division : division
        user = RoleAssignment.holder_for(
          review_role: hierarchy_role.review_role,
          division: owner.is_a?(Division) ? owner : nil,
          sub_division: owner.is_a?(SubDivision) ? owner : nil
        )
        next if user.nil?

        raiseable = if owner.is_a?(SubDivision)
          owner.effective_can_raise_on_behalf?(hierarchy_role.review_role)
        else
          false
        end

        ResolvedStep.new(
          hierarchy_role: hierarchy_role,
          user: user,
          review_role: hierarchy_role.review_role,
          can_raise_on_behalf: raiseable,
          scope_owner: owner
        )
      end
    end
  end

  def current_reviewer
    current_resolved_step&.user
  end

  def current_resolved_step
    return nil if @request.current_review_role_id.blank?

    review_chain.find { |resolved| resolved.review_role_id == @request.current_review_role_id }
  end

  def next_step
    idx = current_index
    return review_chain.first if idx.nil? && @request.current_review_role_id.blank?

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

  def entry_step_for_submit
    first_step
  end

  def entry_step_for_raise_on_behalf(actor:)
    chain = review_chain
    initiator_index = chain.index do |resolved|
      resolved.can_raise_on_behalf? && resolved.user.id == actor.id
    end
    return chain[initiator_index + 1] if initiator_index && chain[initiator_index + 1]

    raiseable_index = chain.index(&:can_raise_on_behalf?)
    return chain[raiseable_index + 1] if raiseable_index && chain[raiseable_index + 1]

    nil
  end

  private

  def hierarchy_roles_for(owner)
    return [] if owner.blank? || owner.hierarchy.blank?

    owner.hierarchy.hierarchy_roles.includes(:review_role, :hierarchy).ordered.to_a
  end

  def current_index
    return nil if @request.current_review_role_id.blank?

    review_chain.index { |resolved| resolved.review_role_id == @request.current_review_role_id }
  end
end
