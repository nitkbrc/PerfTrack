class SubDivision < ApplicationRecord
  belongs_to :division
  belongs_to :supervisor, class_name: "User", foreign_key: :supervisor_user_id

  has_many :categories

  validate :supervisor_is_not_a_dean

  private

  # Mirror image of Division#dean_is_not_a_supervisor (TRD section 6).
  def supervisor_is_not_a_dean
    if Division.exists?(dean_user_id: supervisor_user_id)
      errors.add(:supervisor_user_id, "is already a dean of a division")
    end
  end
end
