module Admin
  class HierarchyStepsController < BaseController
    before_action :set_owner

    def index
      authorize HierarchyStep
      @steps = @owner.hierarchy_steps.includes(:review_role).ordered
      @available_roles = available_roles_for_owner
    end

    def create
      authorize HierarchyStep
      step = @owner.hierarchy_steps.build(step_params)
      step.position = (@owner.hierarchy_steps.maximum(:position) || 0) + 1
      if step.save
        redirect_to owner_steps_path, notice: "Step added."
      else
        redirect_to owner_steps_path, alert: step.errors.full_messages.to_sentence
      end
    end

    def update
      step = authorize @owner.hierarchy_steps.find(params[:id])
      if step.update(step_update_params)
        redirect_to owner_steps_path, notice: "Step updated."
      else
        redirect_to owner_steps_path, alert: step.errors.full_messages.to_sentence
      end
    end

    def destroy
      step = authorize @owner.hierarchy_steps.find(params[:id])
      step.destroy!
      renumber_steps!
      redirect_to owner_steps_path, notice: "Step removed."
    end

    def move_up
      step = authorize @owner.hierarchy_steps.find(params[:id])
      swap_with(step, -1)
      redirect_to owner_steps_path
    end

    def move_down
      step = authorize @owner.hierarchy_steps.find(params[:id])
      swap_with(step, 1)
      redirect_to owner_steps_path
    end

    def bulk_apply
      authorize HierarchyStep
      target_ids = Array(params[:target_ids]).map(&:presence).compact
      if target_ids.blank?
        return redirect_to owner_steps_path, alert: "Select at least one target."
      end

      source_steps = @owner.hierarchy_steps.includes(:review_role).ordered.to_a
      targets = bulk_targets(target_ids)
      HierarchyStep.transaction do
        targets.each do |target|
          target.hierarchy_steps.destroy_all
          source_steps.each do |source|
            target.hierarchy_steps.create!(
              review_role: source.review_role,
              position: source.position,
              can_raise_on_behalf: source.can_raise_on_behalf
            )
          end
        end
      end
      redirect_to owner_steps_path, notice: "Hierarchy copied to #{targets.size} #{owner_label.pluralize}."
    end

    private

    def set_owner
      if params[:division_id]
        @owner = Division.find(params[:division_id])
        @owner_type = :division
      elsif params[:sub_division_id]
        @owner = SubDivision.find(params[:sub_division_id])
        @owner_type = :sub_division
      else
        raise ActiveRecord::RecordNotFound
      end
    end

    def owner_steps_path
      if @owner_type == :division
        admin_division_hierarchy_steps_path(@owner)
      else
        admin_sub_division_hierarchy_steps_path(@owner)
      end
    end

    def owner_label
      @owner_type == :division ? "division" : "sub-division"
    end

    def available_roles_for_owner
      scope = @owner_type == :division ? ReviewRole.scope_division : ReviewRole.scope_sub_division
      used = @owner.hierarchy_steps.select(:review_role_id)
      scope.where.not(id: used).order(:name)
    end

    def step_params
      params.expect(hierarchy_step: [ :review_role_id, :can_raise_on_behalf ])
    end

    def step_update_params
      params.expect(hierarchy_step: [ :can_raise_on_behalf ])
    end

    def swap_with(step, direction)
      other = @owner.hierarchy_steps.find_by(position: step.position + direction)
      return unless other

      HierarchyStep.transaction do
        temporary = -step.position
        other_pos = other.position
        step_pos = step.position
        step.update_columns(position: temporary)
        other.update_columns(position: step_pos)
        step.update_columns(position: other_pos)
      end
    end

    def renumber_steps!
      @owner.hierarchy_steps.ordered.each.with_index(1) do |step, index|
        step.update_columns(position: index)
      end
    end

    def bulk_targets(ids)
      if @owner_type == :division
        Division.where(id: ids).where.not(id: @owner.id)
      else
        SubDivision.where(id: ids).where.not(id: @owner.id)
      end
    end
  end
end
