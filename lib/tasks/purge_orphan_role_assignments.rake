namespace :admin do
  desc "Remove role assignments whose review role is no longer on the owner's hierarchy template"
  task purge_orphan_role_assignments: :environment do
    removed = 0

    RoleAssignment.includes(:review_role, :division, :sub_division).find_each do |assignment|
      owner = assignment.division || assignment.sub_division
      next if owner.blank?

      hierarchy = owner.hierarchy
      next if hierarchy.blank?
      next if hierarchy.hierarchy_roles.exists?(review_role_id: assignment.review_role_id)

      puts "Removing #{assignment.review_role&.name} on #{owner.name} (#{owner.class.name} ##{owner.id}) held by #{assignment.user&.email}"
      assignment.destroy!
      removed += 1
    end

    puts "Done. Removed #{removed} orphan assignment#{'s' unless removed == 1}."
  end
end
