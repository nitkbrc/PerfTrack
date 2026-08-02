module Admin
  class RoleAssignmentsController < BaseController
    def index
      authorize RoleAssignment
      @assignments = RoleAssignment.includes(:user, :review_role, :division, :sub_division)
                                   .order(created_at: :desc)
      @review_roles = ReviewRole.order(:scope, :name)
    end

    def new
      @assignment = authorize RoleAssignment.new(review_role_id: params[:review_role_id],
                                                 division_id: params[:division_id],
                                                 sub_division_id: params[:sub_division_id])
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

    def load_form_collections
      ReviewRole.ensure_system_roles!
      @review_roles = ReviewRole.order(:scope, :name)
      @divisions = Division.active.order(:name)
      @sub_divisions = SubDivision.active.includes(:division).order(:name)
      role = @assignment.review_role || ReviewRole.find_by(id: @assignment.review_role_id)
      @eligible_users = if role
        User.eligible_for_role(role, keep_user_id: @assignment.user_id).order(:name)
      else
        User.faculty.order(:name)
      end
    end
  end
end
