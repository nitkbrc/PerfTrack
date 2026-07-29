class AchievementRequest < ApplicationRecord
  belongs_to :student
  belongs_to :category

  has_many :req_histories
  has_many :request_versions, dependent: :destroy
  has_many :notifications, dependent: :destroy

  validates :title, presence: true

  # Backend guard behind the picker filtering: archived (soft-deleted)
  # categories keep their existing requests but never accept new ones.
  validate :category_is_not_archived, on: :create

  enum :status, { submitted: "submitted", supervisor_approved: "supervisor_approved",
                  supervisor_reverted: "supervisor_reverted", dean_approved: "dean_approved",
                  dean_reverted: "dean_reverted", rejected: "rejected" }

  # Actions that lock a version as sent (immutable snapshot). Edits after that
  # create a new draft; further edits coalesce onto that draft until the next send.
  VERSION_SENT_ACTIONS = %w[
    submit
    resubmit
    supervisor_initiate
    supervisor_reforward
  ].freeze

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

  # Path A submission: the request, first version, and first history row are
  # created in one transaction so none can exist without the others.
  def self.submit!(student:, actor:, attrs:)
    attrs, proofs = split_proofs(attrs)
    request = transaction do
      created = create!(attrs.merge(student: student, status: :submitted))
      version = created.create_version!(version_number: 1, proofs: proofs)
      created.req_histories.create!(actor: actor, action: "submit", to_status: "submitted",
                                    request_version: version)
      created
    end
    RequestMailer.submitted_to_supervisor(request, actor: actor).deliver_later
    request
  end

  # Path A vs Path B origin — the first history row is the source of truth.
  def student_initiated?
    req_histories.order(:created_at).first&.action == "submit"
  end

  # Path B: the supervisor creating the request is itself the review step, so it
  # skips submitted; the first history row records the supervisor as originator.
  def self.supervisor_initiate!(student:, actor:, attrs:)
    attrs, proofs = split_proofs(attrs)
    request = transaction do
      created = create!(attrs.merge(student: student, status: :supervisor_approved))
      version = created.create_version!(version_number: 1, proofs: proofs)
      created.req_histories.create!(actor: actor, action: "supervisor_initiate",
                                    to_status: "supervisor_approved",
                                    request_version: version)
      created
    end
    RequestMailer.raised_on_behalf(request, actor: actor).deliver_later
    request
  end

  # Student edit-and-resubmit after supervisor_reverted: new version + history.
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
      update!(title: version.title, description: version.description, status: :submitted)
      req_histories.create!(actor: actor, action: "resubmit",
                            from_status: from, to_status: "submitted",
                            request_version: version)
    end
    RequestMailer.submitted_to_supervisor(self, actor: actor).deliver_later
    self
  end

  # Path B supervisor fix-up after dean_reverted.
  # First edit after a sent version creates a draft (N+1); further saves update
  # that draft in place until re-forward locks it.
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

  # Every review transition writes its history row in the same transaction as
  # the status change (PRD section 6 — auditability).
  def transition!(to:, actor:, action:, comment: nil, reason_template: nil)
    transaction do
      from = status
      update!(status: to)
      req_histories.create!(actor: actor, action: action, comment: comment,
                            reason_template: reason_template,
                            from_status: from, to_status: to.to_s,
                            request_version: current_version)
    end
    enqueue_transition_mail!(actor: actor, action: action, comment: comment)
    self
  end

  # Dean approval snapshots the signed point value in the same transaction as
  # the status change and its history row (TRD section 6), so later
  # category.points edits never retroactively change an already-verified record.
  def dean_approve!(actor:)
    transaction do
      sign = category.sub_division.division.positive? ? 1 : -1
      from = status
      update!(status: :dean_approved, points_awarded: category.points * sign)
      req_histories.create!(actor: actor, action: "dean_approve",
                            from_status: from, to_status: "dean_approved",
                            request_version: current_version)
    end
    # Enqueued after the transaction commits so the job never sees a rolled-back
    # approval (PRD section 8 — notify on verification).
    DeanApprovalNotificationJob.perform_later(id)
    enqueue_final_decision_mails!(:approved_notification, actor: actor)
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

  # Snapshot a new version from the previous one, carrying forward existing
  # proofs (minus any marked for removal) and appending newly uploaded files.
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

  private

  def enqueue_transition_mail!(actor:, action:, comment:)
    case action.to_s
    when "supervisor_approve"
      RequestMailer.forwarded_to_dean(self, actor: actor, is_reforward: false).deliver_later
    when "supervisor_reforward"
      RequestMailer.forwarded_to_dean(self, actor: actor, is_reforward: true).deliver_later
    when "dean_revert"
      RequestMailer.reverted_to_supervisor(self, actor: actor, comment: comment).deliver_later
    when "supervisor_revert"
      RequestMailer.reverted_to_student(self, actor: actor, comment: comment).deliver_later
    when "supervisor_reject"
      # Submitted → Rejected is always student-originated; student only.
      RequestMailer.rejected_notification(self, actor: actor, recipient: student.user,
                                          comment: comment).deliver_later
    when "dean_reject"
      enqueue_final_decision_mails!(:rejected_notification, actor: actor, comment: comment)
    end
  end

  # Path B origin: first ReqHistory actor is the supervisor who raised on behalf
  # of the student (not the student themselves).
  def originating_supervisor
    first = req_histories.order(:created_at).first
    return nil if first.nil? || first.actor_id == student.user_id

    first.actor
  end

  # Dean final decision (approve or reject): always the student; Path B also the
  # originating supervisor from the first history row.
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
end
