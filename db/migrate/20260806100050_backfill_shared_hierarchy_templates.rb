class BackfillSharedHierarchyTemplates < ActiveRecord::Migration[8.1]
  # Local model so this migration does not depend on Division/SubDivision
  # still exposing has_many :hierarchy_steps (removed after cutover).
  class LegacyHierarchyStep < ActiveRecord::Base
    self.table_name = "hierarchy_steps"
  end

  def up
    unless table_exists?(:hierarchy_steps)
      say "hierarchy_steps already gone — seeding defaults and attaching owners only"
      Hierarchy.ensure_defaults!
      Division.where(hierarchy_id: nil).update_all(hierarchy_id: Hierarchy.default_for("division").id)
      SubDivision.where(hierarchy_id: nil).update_all(hierarchy_id: Hierarchy.default_for("sub_division").id)
      return
    end

    say_with_time "Seed default hierarchies" do
      Hierarchy.ensure_defaults!
    end

    say_with_time "Group division HierarchySteps into shared templates" do
      backfill_owners(Division, "division", :division_id)
    end

    say_with_time "Group sub-division HierarchySteps into shared templates" do
      backfill_owners(SubDivision, "sub_division", :sub_division_id)
    end

    say_with_time "Copy raiseable overrides for sub-divisions" do
      copy_raiseable_overrides
    end

    say_with_time "Map current_step_id → current_review_role_id" do
      map_current_review_roles
    end
  end

  def down
    AchievementRequest.update_all(current_review_role_id: nil)
    SubDivisionRaiseableOverride.delete_all
    Division.update_all(hierarchy_id: nil)
    SubDivision.update_all(hierarchy_id: nil)
    HierarchyRole.delete_all
    Hierarchy.delete_all
  end

  private

  def backfill_owners(owner_class, scope, owner_fk)
    defaults = Hierarchy.default_for(scope)
    signature_map = {}

    owner_class.find_each do |owner|
      steps = LegacyHierarchyStep.where(owner_fk => owner.id).order(:position).to_a
      if steps.empty?
        owner.update_columns(hierarchy_id: defaults.id)
        next
      end

      signature = steps.map { |s| [ s.review_role_id, s.can_raise_on_behalf ] }
      hierarchy = signature_map[signature]

      unless hierarchy
        if default_signature?(signature, scope)
          hierarchy = defaults
        else
          hierarchy = Hierarchy.create!(
            name: unique_template_name(scope, owner.name),
            scope: scope,
            is_default: false
          )
          steps.each_with_index do |step, index|
            hierarchy.hierarchy_roles.create!(
              review_role_id: step.review_role_id,
              position: index + 1,
              can_raise_on_behalf: step.can_raise_on_behalf
            )
          end
        end
        signature_map[signature] = hierarchy
      end

      owner.update_columns(hierarchy_id: hierarchy.id)
    end
  end

  def default_signature?(signature, scope)
    if scope == "division"
      dean = ReviewRole.find_by(name: ReviewRole::DEAN)
      return false unless dean

      signature == [ [ dean.id, false ] ]
    else
      supervisor = ReviewRole.find_by(name: ReviewRole::SUPERVISOR)
      return false unless supervisor

      signature == [ [ supervisor.id, true ] ]
    end
  end

  def unique_template_name(scope, owner_name)
    base = "#{scope == 'division' ? 'Division' : 'Sub-division'} chain — #{owner_name}"
    name = base
    n = 2
    while Hierarchy.exists?(name: name)
      name = "#{base} (#{n})"
      n += 1
    end
    name
  end

  def copy_raiseable_overrides
    raiseable_role_ids = ReviewRole.where(raiseable_on_behalf_eligible: true).pluck(:id)
    return if raiseable_role_ids.empty?

    SubDivision.find_each do |sub|
      hierarchy = sub.hierarchy
      next unless hierarchy

      template_defaults = hierarchy.hierarchy_roles.index_by(&:review_role_id)
      LegacyHierarchyStep.where(sub_division_id: sub.id, review_role_id: raiseable_role_ids).find_each do |step|
        template = template_defaults[step.review_role_id]
        next unless template
        next if step.can_raise_on_behalf == template.can_raise_on_behalf?

        SubDivisionRaiseableOverride.find_or_create_by!(
          sub_division_id: sub.id,
          review_role_id: step.review_role_id
        ) do |override|
          override.can_raise_on_behalf = step.can_raise_on_behalf
        end
      end
    end
  end

  def map_current_review_roles
    return unless column_exists?(:achievement_requests, :current_step_id)

    execute <<~SQL.squish
      UPDATE achievement_requests
      SET current_review_role_id = hierarchy_steps.review_role_id
      FROM hierarchy_steps
      WHERE achievement_requests.current_step_id = hierarchy_steps.id
        AND achievement_requests.current_review_role_id IS NULL
    SQL
  end
end
