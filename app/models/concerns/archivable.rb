# Soft deletion for the division tree. Archived records stay in the database
# (so approved requests and audit history keep working) but stop appearing in
# pickers for new requests.
module Archivable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(archived_at: nil) }
    scope :archived, -> { where.not(archived_at: nil) }
  end

  def archived?
    archived_at.present?
  end
end
