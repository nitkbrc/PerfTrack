module Admin
  module RoleSlotsHelper
    # Slots in review order (step 1 = first reviewer), derived from the owner's
    # hierarchy template and matched against existing role_assignments.
    def role_slots_for(owner)
      roles = owner.hierarchy&.hierarchy_roles&.sort_by(&:position) || []
      by_role = owner.role_assignments.index_by(&:review_role_id)

      roles.each_with_index.map do |hr, index|
        RoleSlot.new(
          review_role: hr.review_role,
          owner: owner,
          assignment: by_role[hr.review_role_id],
          step: index + 1
        )
      end
    end

    def role_slot_assign_path(slot)
      params = { review_role_id: slot.review_role.id }
      if slot.owner.is_a?(Division)
        params[:division_id] = slot.owner.id
      else
        params[:sub_division_id] = slot.owner.id
      end
      new_admin_role_assignment_path(params)
    end

    def role_slot_owner_label(owner)
      if owner.is_a?(SubDivision)
        "#{owner.division.name} / #{owner.name}"
      else
        owner.name
      end
    end

    def role_slots_staffed_summary(slots)
      total = slots.size
      staffed = slots.count { |slot| !slot.vacant? }
      "#{staffed} of #{total} staffed"
    end
  end
end
