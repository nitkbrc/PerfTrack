module Admin
  class RoleAssignmentsController < BaseController
    helper Admin::RoleSlotsHelper

    def index
      authorize RoleAssignment
      @divisions = Division.active
                           .includes(
                             :hierarchy,
                             hierarchy: { hierarchy_roles: :review_role },
                             role_assignments: [ :user, :review_role ],
                             sub_divisions: [
                               :hierarchy,
                               { hierarchy: { hierarchy_roles: :review_role } },
                               { role_assignments: [ :user, :review_role ] }
                             ]
                           )
                           .order(:name)
      @stats = index_stats(@divisions)
    end

    def new
      authorize RoleAssignment

      unless slot_params_present?
        redirect_to admin_role_assignments_path,
                    alert: "Pick a vacant role slot from the list to assign someone."
        return
      end

      @assignment = RoleAssignment.new(
        review_role_id: params[:review_role_id],
        division_id: params[:division_id],
        sub_division_id: params[:sub_division_id]
      )
      load_form_collections
    end

    def create
      @assignment = authorize RoleAssignment.new(assignment_params)
      if @assignment.save
        redirect_to admin_role_assignments_path, notice: "Role assigned."
      else
        load_form_collections
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @assignment = authorize RoleAssignment.find(params[:id])
      load_form_collections
    end

    def update
      @assignment = authorize RoleAssignment.find(params[:id])
      if @assignment.update(assignment_params)
        redirect_to admin_role_assignments_path, notice: "Assignment updated."
      else
        load_form_collections
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      assignment = authorize RoleAssignment.find(params[:id])
      assignment.destroy!
      redirect_to admin_role_assignments_path, notice: "Assignment removed."
    end

    private

    def assignment_params
      params.expect(role_assignment: [ :user_id, :review_role_id, :division_id, :sub_division_id ])
    end

    def slot_params_present?
      params[:review_role_id].present? &&
        (params[:division_id].present? ^ params[:sub_division_id].present?)
    end

    def load_form_collections
      ReviewRole.ensure_system_roles!
      role = @assignment.review_role || ReviewRole.find_by(id: @assignment.review_role_id)
      @review_role = role
      @owner = if @assignment.division_id.present?
        Division.find_by(id: @assignment.division_id)
      elsif @assignment.sub_division_id.present?
        SubDivision.includes(:division).find_by(id: @assignment.sub_division_id)
      end
      @eligible_users = if role
        User.eligible_for_role(role, keep_user_id: @assignment.user_id).order(:name)
      else
        User.faculty.order(:name)
      end
    end

    def index_stats(divisions)
      total_slots = 0
      staffed = 0
      vacant = 0
      no_template = 0

      divisions.each do |division|
        if division.hierarchy_id.blank?
          no_template += 1
        else
          roles = division.hierarchy.hierarchy_roles
          assigned_ids = division.role_assignments.map(&:review_role_id)
          total_slots += roles.size
          staffed += roles.count { |hr| assigned_ids.include?(hr.review_role_id) }
          vacant += roles.count { |hr| assigned_ids.exclude?(hr.review_role_id) }
        end

        division.sub_divisions.select { |sd| sd.archived_at.blank? }.each do |sub|
          if sub.hierarchy_id.blank?
            no_template += 1
          else
            roles = sub.hierarchy.hierarchy_roles
            assigned_ids = sub.role_assignments.map(&:review_role_id)
            total_slots += roles.size
            staffed += roles.count { |hr| assigned_ids.include?(hr.review_role_id) }
            vacant += roles.count { |hr| assigned_ids.exclude?(hr.review_role_id) }
          end
        end
      end

      { total_slots: total_slots, staffed: staffed, vacant: vacant, no_template: no_template }
    end
  end
end
