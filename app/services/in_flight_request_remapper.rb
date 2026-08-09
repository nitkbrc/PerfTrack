# Places in-flight AchievementRequests onto a new live review chain after a
# hierarchy template edit or owner reattachment.
#
# Placement uses roles already passed on the old chain:
# - last passed role that still appears on the new chain → next role after it
# - no overlap → first new role
# - entire new chain already passed → last new role (human final decision; never auto-approve)
class InFlightRequestRemapper
  class EmptyChain < StandardError; end

  def self.landing_role_id(old_chain_role_ids:, current_role_id:, new_chain_role_ids:)
    new_ids = Array(new_chain_role_ids).map(&:to_i)
    raise EmptyChain, "new review chain has no staffed roles" if new_ids.empty?

    old_ids = Array(old_chain_role_ids).map(&:to_i)
    current_id = current_role_id&.to_i

    passed =
      if current_id.present? && (idx = old_ids.index(current_id))
        old_ids[0...idx]
      else
        []
      end

    last_passed_index = nil
    new_ids.each_with_index do |role_id, index|
      last_passed_index = index if passed.include?(role_id)
    end

    if last_passed_index.nil?
      new_ids.first
    elsif last_passed_index >= new_ids.length - 1
      new_ids.last
    else
      new_ids[last_passed_index + 1]
    end
  end

  def initialize(actor:)
    @actor = actor
  end

  # Returns true when the request was updated.
  def remap!(request:, old_chain_role_ids:, new_chain_role_ids: nil)
    request = request.reload
    return false unless request.in_review?

    new_ids = Array(new_chain_role_ids).presence || staffed_chain_role_ids(request)
    old_ids = Array(old_chain_role_ids).map(&:to_i)

    begin
      landing_id = self.class.landing_role_id(
        old_chain_role_ids: old_ids,
        current_role_id: request.current_review_role_id,
        new_chain_role_ids: new_ids
      )
    rescue EmptyChain
      owner = request.category.sub_division
      raise HierarchyBulkSave::Error,
            "Cannot save: “#{request.title}” has nowhere to land on #{owner.name}'s review chain. Staff at least one role, then try again."
    end

    previous_role_id = request.current_review_role_id

    chain_changed = old_ids != new_ids.map(&:to_i)
    role_changed = previous_role_id != landing_id
    return false unless chain_changed || role_changed

    landing_role = ReviewRole.find(landing_id)
    from_status = request.status

    request.update!(current_review_role: landing_role)

    version = request.current_version || request.request_versions.order(:version_number).last
    raise HierarchyBulkSave::Error, "Request “#{request.title}” has no version to audit" if version.blank?

    request.req_histories.create!(
      actor: @actor,
      action: "hierarchy_reassigned",
      comment: "Review path updated after a hierarchy change. Now awaiting #{landing_role.name}.",
      from_status: from_status,
      to_status: request.status,
      request_version: version
    )

    notify!(request, landing_role: landing_role)
    true
  end

  def self.staffed_chain_role_ids(request)
    ReviewChainResolver.new(request).review_chain.map(&:review_role_id)
  end

  private

  def staffed_chain_role_ids(request)
    self.class.staffed_chain_role_ids(request)
  end

  def notify!(request, landing_role:)
    reviewer = request.current_reviewer
    student_user = request.student.user

    if reviewer
      RequestMailer.hierarchy_reassigned_to_reviewer(
        request,
        actor: @actor,
        recipient: reviewer,
        landing_role: landing_role
      ).deliver_later
    end

    RequestMailer.hierarchy_reassigned_to_student(
      request,
      actor: @actor,
      landing_role: landing_role,
      reviewer: reviewer
    ).deliver_later

    message = if reviewer
      "Review path for \"#{request.title}\" was updated after a hierarchy change. Now awaiting #{landing_role.name} (#{reviewer.name.presence || reviewer.email})."
    else
      "Review path for \"#{request.title}\" was updated after a hierarchy change. Now awaiting #{landing_role.name}."
    end

    Notification.create!(
      recipient: student_user,
      achievement_request: request,
      message: message,
      read: false
    )
  end
end
