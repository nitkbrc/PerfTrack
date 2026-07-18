class Category < ApplicationRecord
  include Archivable

  belongs_to :sub_division

  has_many :achievement_requests

  def archive!(stamp = Time.current)
    update!(archived_at: stamp)
  end

  def restore!
    update!(archived_at: nil)
  end
end
