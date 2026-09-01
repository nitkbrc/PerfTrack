class AchievementRequest < ApplicationRecord
  belongs_to :student
  belongs_to :category
  belongs_to :current_review_role, class_name: "ReviewRole", optional: true
  belongs_to :originating_review_role, class_name: "ReviewRole", optional: true

  RAISER_ROLE_REMOVED_MESSAGE =
    "This request can only be approved or rejected because the raising role is no longer on the review chain.".freeze

  # Histories must go before versions: versions restrict destroy while histories remain.
  has_many :req_histories, dependent: :destroy
  has_many :request_versions, dependent: :destroy
  has_many :notifications, dependent: :destroy

  validates :title, presence: true

  # Backend guard behind the picker filtering: archived (soft-deleted)
  # categories keep their existing requests but never accept new ones.
  validate :category_is_not_archived, on: :create
  validate :hierarchy_must_be_staffed, on: :create

  enum :status, {
    in_review: "in_review",
    reverted: "reverted",
    approved: "approved",
    rejected: "rejected"
  }

  scope :for_current_reviewer, ->(user) {
    in_review
      .joins(category: { sub_division: :division })
      .joins(<<~SQL.squish)
        INNER JOIN role_assignments ON role_assignments.review_role_id = achievement_requests.current_review_role_id
          AND role_assignments.user_id = #{user.id.to_i}
          AND (
            (role_assignments.sub_division_id IS NOT NULL AND role_assignments.sub_division_id = sub_divisions.id)
            OR
            (role_assignments.division_id IS NOT NULL AND role_assignments.division_id = divisions.id)
          )
      SQL
  }

  # Actions that lock a version as sent (immutable snapshot). Edits after that
  # create a new draft; further edits coalesce onto that draft until the next send.
  VERSION_SENT_ACTIONS = %w[
    submit
    resubmit
    supervisor_initiate
    advance
  ].freeze

  def review_chain_resolver
    ReviewChainResolver.new(self)
  end

  delegate :review_chain, :current_reviewer, :next_step, :previous_step, to: :review_chain_resolver

  def current_version
    request_versions.order(version_number: :desc).first
  end

  def version_sent?(version)
    version.req_histories.exists?(action: VERSION_SENT_ACTIONS)
  end

  def current_version_sent?
    version = current_version
    version.present? && version_sent?(version)
  end

  # Proofs live on RequestVersion; convenience for views/controllers that still
  # read request.proofs (always the latest version's attachments).
  delegate :proofs, to: :current_version

  # Path A submission: lands on the first assigned chain step (typically Supervisor).
  def self.submit!(student:, actor:, attrs:)
    attrs, proofs = split_proofs(attrs)
    request = transaction do
      created = create!(attrs.merge(student: student, status: :in_review))
      entry = created.review_chain_resolver.entry_step_for_submit
      unless entry
        created.errors.add(:base, "No reviewer is assigned for this category's review chain")
        raise ActiveRecord::RecordInvalid, created
      end

      created.update!(current_review_role: entry.review_role)
      version = created.create_version!(version_number: 1, proofs: proofs)
      created.req_histories.create!(actor: actor, action: "submit", to_status: "in_review",
                                    request_version: version)
      created
    end
    notify_current_reviewer!(request, actor: actor, kind: :submitted)
    request
  end

  # Path A vs Path B origin — the first history row is the source of truth.
  def student_initiated?
    req_histories.order(:created_at).first&.action == "submit"
  end

  # Path B: skip the raiseable initiator's step; land on the next assigned step
  # (typically Dean in the default 2-step hierarchy).
  def self.supervisor_initiate!(student:, actor:, attrs:)
    attrs, proofs = split_proofs(attrs)
    request = transaction do
      created = create!(attrs.merge(student: student, status: :in_review))
      resolver = created.review_chain_resolver
      initiator = resolver.raise_on_behalf_initiator(actor: actor)
      entry = resolver.entry_step_for_raise_on_behalf(actor: actor)
      raise ActiveRecord::RecordInvalid, created unless entry

      created.update!(
        current_review_role: entry.review_role,
        originating_review_role: initiator&.review_role
      )
      version = created.create_version!(version_number: 1, proofs: proofs)
      created.req_histories.create!(actor: actor, action: "supervisor_initiate",
                                    to_status: "in_review",
                                    request_version: version)
      created
    end
    notify_current_reviewer!(request, actor: actor, kind: :raised_on_behalf)
    RequestMailer.raised_on_your_behalf(request, actor: actor).deliver_later
    request
  end

  # Student (or Path B floor creator) edit-and-resubmit after reverted.
  def resubmit!(actor:, attrs:)
    attrs, new_proofs, remove_proof_ids = self.class.split_proof_attrs(attrs)
    transaction do
      version = if current_version_sent?
        append_version!(title: attrs[:title], description: attrs[:description],
                        new_proofs: new_proofs, remove_proof_ids: remove_proof_ids)
      else
        update_version!(current_version, title: attrs[:title], description: attrs[:description],
                                         new_proofs: new_proofs, remove_proof_ids: remove_proof_ids)
      end
      from = status
      entry = review_chain_resolver.entry_step_for_submit
      update!(title: version.title, description: version.description,
              status: :in_review, current_review_role: entry&.review_role)
      req_histories.create!(actor: actor, action: "resubmit",
                            from_status: from, to_status: "in_review",
                            request_version: version)
    end
    self.class.notify_current_reviewer!(self, actor: actor, kind: :submitted)
    self
  end

  # Path B supervisor fix-up while the request sits at their raiseable step
  # after a later reviewer reverted.
  def revise!(actor:, attrs:)
    attrs, new_proofs, remove_proof_ids = self.class.split_proof_attrs(attrs)
    transaction do
      if current_version_sent?
        version = append_version!(title: attrs[:title], description: attrs[:description],
                                  new_proofs: new_proofs, remove_proof_ids: remove_proof_ids)
        update!(title: version.title, description: version.description)
        req_histories.create!(actor: actor, action: "supervisor_revise",
                              from_status: status, to_status: status,
                              request_version: version)
      else
        version = update_version!(current_version, title: attrs[:title], description: attrs[:description],
                                                   new_proofs: new_proofs, remove_proof_ids: remove_proof_ids)
        update!(title: version.title, description: version.description)
      end
    end
  end

  def remove_saved_proof!(actor:, signed_id:, draft_action: nil)
    transaction do
      version = editable_version_for!(actor: actor, draft_action: draft_action)
      proof = version.proofs.find { |attachment| attachment.signed_id == signed_id.to_s }
      raise ActiveRecord::RecordNotFound, "Proof not found" unless proof
      raise ActiveRecord::RecordInvalid, version if version.proofs.count <= 1

      proof.purge
    end
  rescue ActiveRecord::RecordInvalid => e
    version = current_version || request_versions.build(category_id: category_id, version_number: 1)
    version.errors.add(:proofs, "must include at least one file")
    raise e
  end

  # Advance to the next assigned chain step, or final-approve when at the last step.
  def advance!(actor:, comment: nil)
    raise ArgumentError, "request is not in review" unless in_review?

    nxt = next_step
    if nxt
      transaction do
        from = status
        update!(current_review_role: nxt.review_role, status: :in_review)
        req_histories.create!(actor: actor, action: "advance", comment: comment,
                              from_status: from, to_status: "in_review",
                              request_version: current_version)
      end
      self.class.notify_current_reviewer!(self, actor: actor, kind: :advanced)
    else
      finalize_approve!(actor: actor)
    end
    self
  end

  # Move to the previous assigned step, or floor to the creator with status reverted.
  def revert!(actor:, comment:, reason_template: nil)
    raise ArgumentError, "request is not in review" unless in_review?
    if raiser_role_removed?
      errors.add(:base, RAISER_ROLE_REMOVED_MESSAGE)
      raise ActiveRecord::RecordInvalid, self
    end

    prev = previous_step
    floored = prev.nil?
    transaction do
      from = status
      if prev
        update!(current_review_role: prev.review_role, status: :in_review)
        req_histories.create!(actor: actor, action: "revert", comment: comment,
                              reason_template: reason_template,
                              from_status: from, to_status: "in_review",
                              request_version: current_version)
      else
        update!(current_review_role: nil, status: :reverted)
        req_histories.create!(actor: actor, action: "revert", comment: comment,
                              reason_template: reason_template,
                              from_status: from, to_status: "reverted",
                              request_version: current_version)
      end
    end
    if floored
      notify_creator_of_revert!(actor: actor, comment: comment)
    else
      self.class.notify_current_reviewer!(self, actor: actor, kind: :reverted, comment: comment)
    end
    self
  end

  def reject!(actor:, comment:, reason_template: nil, action: "reject")
    transaction do
      from = status
      update!(status: :rejected, current_review_role: nil, **catalog_snapshot_attributes)
      req_histories.create!(actor: actor, action: action, comment: comment,
                            reason_template: reason_template,
                            from_status: from, to_status: "rejected",
                            request_version: current_version)
    end
    enqueue_final_decision_mails!(:rejected_notification, actor: actor, comment: comment)
    self
  end

  # Kept for archive auto-reject and any remaining callers that need a generic write.
  def transition!(to:, actor:, action:, comment: nil, reason_template: nil)
    if to.to_sym == :rejected
      return reject!(actor: actor, comment: comment, reason_template: reason_template, action: action.to_s)
    end

    transaction do
      from = status
      update!(status: to)
      req_histories.create!(actor: actor, action: action, comment: comment,
                            reason_template: reason_template,
                            from_status: from, to_status: to.to_s,
                            request_version: current_version)
    end
    self
  end

  def create_version!(version_number:, proofs:, title: self.title, description: self.description)
    version = request_versions.build(
      version_number: version_number,
      title: title,
      description: description,
      category_id: category_id
    )
    Array(proofs).each { |proof| version.proofs.attach(proof) }
    version.save!
    version
  end

  def append_version!(title:, description:, new_proofs: [], remove_proof_ids: [])
    previous = current_version
    kept = previous.proofs.reject { |proof| remove_proof_ids.include?(proof.signed_id) }
                   .map(&:blob)
    create_version!(
      version_number: previous.version_number + 1,
      title: title,
      description: description,
      proofs: kept + Array(new_proofs)
    )
  end

  def editable_version_for!(actor:, draft_action: nil)
    return current_version unless current_version_sent?

    version = append_version!(title: title, description: description)
    if draft_action.present?
      req_histories.create!(actor: actor, action: draft_action,
                            from_status: status, to_status: status,
                            request_version: version)
    end
    update!(title: version.title, description: version.description)
    version
  end

  def update_version!(version, title:, description:, new_proofs: [], remove_proof_ids: [])
    version.assign_attributes(title: title, description: description)
    purge_proofs!(version, remove_proof_ids)
    version.proofs.attach(new_proofs) if new_proofs.present?
    version.save!
    version
  end

  def purge_proofs!(version, remove_proof_ids)
    return if remove_proof_ids.blank?

    version.proofs.each do |proof|
      proof.purge if remove_proof_ids.include?(proof.signed_id)
    end
  end

  def self.split_proofs(attrs)
    attrs, proofs, _remove_ids = split_proof_attrs(attrs)
    [ attrs, proofs ]
  end

  def self.split_proof_attrs(attrs)
    attrs = attrs.to_unsafe_h if attrs.respond_to?(:to_unsafe_h)
    attrs = attrs.symbolize_keys
    proofs = Array(attrs.delete(:proofs)).reject(&:blank?)
    remove_ids = Array(attrs.delete(:remove_proof_ids)).reject(&:blank?).map(&:to_s)
    [ attrs, proofs, remove_ids ]
  end

  # Path B lock: the role that raised this request is no longer on the unit's template.
  # Nil originating role (legacy Path B) is not locked.
  def raiser_role_removed?
    return false if student_initiated? || originating_review_role_id.blank?

    roles = category.sub_division.hierarchy&.hierarchy_roles
    return true if roles.nil?

    !roles.exists?(review_role_id: originating_review_role_id)
  end

  # True when the request sits at a raiseable-on-behalf step (Path B edit window).
  def awaiting_raiseable_revision?
    return false unless in_review? && current_review_role_id.present? && !student_initiated?

    resolved = review_chain_resolver.current_resolved_step
    resolved&.can_raise_on_behalf?
  end

  # Final approver's role name for student-facing copy. current_review_role is
  # cleared on approval, so read it back from the approving actor's assignment on
  # this request's owners rather than the chain, which may have changed since.
  # nil when it cannot be determined — callers must degrade to role-free wording.
  def approving_review_role_name
    approval = req_histories.select { |history| history.to_status == "approved" }.max_by(&:created_at)
    return nil if approval.nil?

    review_role_name_for(approval.actor)
  end

  # Review role the actor holds over this request's owners, preferring the
  # division-scoped assignment. nil when they hold none — callers must degrade
  # to role-free wording.
  def review_role_name_for(actor)
    return nil if actor.nil?

    sub_division = category.sub_division
    assignments = RoleAssignment.includes(:review_role).where(user_id: actor.id)
    assignment = assignments.find_by(division_id: sub_division.division_id) ||
                 assignments.find_by(sub_division_id: sub_division.id)
    assignment&.review_role&.name
  end

  def decided?
    approved? || rejected?
  end

  def catalog_snapshot_present?
    snapshot_category_name.present?
  end

  def use_catalog_snapshot?
    decided? && catalog_snapshot_present?
  end

  def display_category_name
    use_catalog_snapshot? ? snapshot_category_name : category.name
  end

  def display_sub_division_name
    use_catalog_snapshot? ? snapshot_sub_division_name : category.sub_division.name
  end

  def display_division_name
    use_catalog_snapshot? ? snapshot_division_name : category.sub_division.division.name
  end

  def display_div_type
    use_catalog_snapshot? ? snapshot_div_type : category.sub_division.division.div_type
  end

  def display_polarity_positive?
    display_div_type == "positive"
  end

  def display_catalog_path
    "#{display_division_name} / #{display_sub_division_name} / #{display_category_name}"
  end

  def raised_on_behalf?
    !student_initiated?
  end

  private

  def finalize_approve!(actor:)
    transaction do
      sign = category.sub_division.division.positive? ? 1 : -1
      from = status
      update!(status: :approved, current_review_role: nil,
              points_awarded: category.points * sign,
              **catalog_snapshot_attributes)
      req_histories.create!(actor: actor, action: "approve",
                            from_status: from, to_status: "approved",
                            request_version: current_version)
    end
    FinalApprovalNotificationJob.perform_later(id)
    enqueue_final_decision_mails!(:approved_notification, actor: actor)
  end

  def catalog_snapshot_attributes
    cat = category
    sub = cat.sub_division
    div = sub.division
    {
      snapshot_category_name: cat.name,
      snapshot_category_points: cat.points,
      snapshot_sub_division_name: sub.name,
      snapshot_division_name: div.name,
      snapshot_div_type: div.div_type
    }
  end

  def self.notify_current_reviewer!(request, actor:, kind:, comment: nil)
    reviewer = request.current_reviewer
    return unless reviewer

    case kind
    when :submitted
      RequestMailer.submitted_to_reviewer(request, actor: actor, recipient: reviewer).deliver_later
    when :raised_on_behalf
      RequestMailer.raised_on_behalf(request, actor: actor, recipient: reviewer).deliver_later
    when :advanced
      RequestMailer.forwarded_to_reviewer(request, actor: actor, recipient: reviewer,
                                          is_reforward: false).deliver_later
    when :reverted
      RequestMailer.reverted_to_reviewer(request, actor: actor, recipient: reviewer,
                                         comment: comment).deliver_later
    end
  end

  def notify_creator_of_revert!(actor:, comment:)
    if student_initiated?
      RequestMailer.reverted_to_student(self, actor: actor, comment: comment).deliver_later
    else
      supervisor = originating_supervisor
      return unless supervisor

      RequestMailer.reverted_to_reviewer(self, actor: actor, recipient: supervisor,
                                         comment: comment).deliver_later
    end
  end

  # Path B origin: first ReqHistory actor is the supervisor who raised on behalf
  # of the student (not the student themselves).
  def originating_supervisor
    first = req_histories.order(:created_at).first
    return nil if first.nil? || first.actor_id == student.user_id

    first.actor
  end

  def enqueue_final_decision_mails!(mailer_method, actor:, comment: nil)
    student_args = { actor: actor, recipient: student.user }
    student_args[:comment] = comment if comment
    RequestMailer.public_send(mailer_method, self, **student_args).deliver_later

    supervisor = originating_supervisor
    return unless supervisor

    supervisor_args = { actor: actor, recipient: supervisor }
    supervisor_args[:comment] = comment if comment
    RequestMailer.public_send(mailer_method, self, **supervisor_args).deliver_later
  end

  def category_is_not_archived
    if category&.archived?
      errors.add(:category, "has been archived and no longer accepts new requests")
    end
  end

  def hierarchy_must_be_staffed
    return if category.blank?

    sub = category.sub_division
    div = sub&.division
    unless sub&.hierarchy_staffed?
      errors.add(:base, "This sub-division's review hierarchy is incomplete — assign all roles before submitting")
    end
    unless div&.hierarchy_staffed?
      errors.add(:base, "This division's review hierarchy is incomplete — assign all roles before submitting")
    end
  end
end
