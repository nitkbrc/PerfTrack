module Admin
  class SubDivisionsController < BaseController
    def index
      authorize SubDivision
      @show_archived = params[:archived].present?
      scope = @show_archived ? SubDivision.archived : SubDivision.active
      @sub_divisions = scope.includes(:division, role_assignments: :user).order(:name)
      @archived_count = SubDivision.archived.count
    end

    def show
      @sub_division = authorize SubDivision.find(params[:id])
      @show_archived = params[:archived].present?
      scope = @show_archived ? @sub_division.categories.archived : @sub_division.categories.active
      @categories = scope.order(:name)
      @archived_count = @sub_division.categories.archived.count
    end

    def new
      @sub_division = authorize SubDivision.new(division_id: params[:division_id])
      load_wizard_collections
    end

    def create
      @sub_division = authorize SubDivision.new(sub_division_params)
      load_wizard_collections

      assignments = params[:assignments]
      assignments = assignments.respond_to?(:permit!) ? assignments.permit!.to_h : {}
      unless wizard_assignments_complete?(@sub_division.hierarchy, assignments)
        @sub_division.errors.add(:base, "Assign a person to every role in the hierarchy")
        render :new, status: :unprocessable_entity
        return
      end

      ActiveRecord::Base.transaction do
        @sub_division.save!
        @sub_division.hierarchy.hierarchy_roles.each do |hr|
          user_id = assignments[hr.review_role_id.to_s]
          RoleAssignment.create!(
            user_id: user_id,
            review_role: hr.review_role,
            sub_division: @sub_division
          )
        end
      end

      redirect_to admin_division_path(@sub_division.division), notice: "Sub-division created."
    rescue ActiveRecord::RecordInvalid => e
      @sub_division = e.record if e.record.is_a?(SubDivision)
      @sub_division ||= SubDivision.new(sub_division_params)
      load_wizard_collections
      render :new, status: :unprocessable_entity
    end

    def edit
      @sub_division = authorize SubDivision.find(params[:id])
    end

    def update
      @sub_division = authorize SubDivision.find(params[:id])
      if @sub_division.update(sub_division_params.slice(:name, :division_id))
        redirect_to admin_division_path(@sub_division.division), notice: "Sub-division updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      sub_division = authorize SubDivision.find(params[:id])
      division = sub_division.division
      sub_division.destroy!
      redirect_to admin_division_path(division), notice: "Sub-division deleted."
    end

    def archive
      sub_division = authorize SubDivision.find(params[:id])
      sub_division.archive!(actor: current_user)
      redirect_to admin_division_path(sub_division.division),
                  notice: "#{sub_division.name} archived, along with its categories."
    end

    def restore
      sub_division = authorize SubDivision.find(params[:id])
      if sub_division.division.archived?
        redirect_to admin_division_path(sub_division.division, archived: 1),
                    alert: "Restore the #{sub_division.division.name} division first."
      else
        sub_division.restore!
        redirect_to admin_division_path(sub_division.division, archived: 1), notice: "#{sub_division.name} restored."
      end
    end

    private

    def sub_division_params
      params.expect(sub_division: [ :name, :division_id, :hierarchy_id ])
    end

    def load_wizard_collections
      Hierarchy.ensure_defaults!
      @divisions = Division.active.order(:name)
      @hierarchies = Hierarchy.scope_sub_division.includes(hierarchy_roles: :review_role).order(:name)
      @hierarchy_options = @hierarchies.map do |h|
        roles = h.hierarchy_roles.includes(:review_role).map do |hr|
          eligible = User.eligible_for_role(hr.review_role).order(:name)
          {
            id: hr.review_role_id,
            name: hr.review_role.name,
            eligible: eligible.map { |u| { id: u.id, label: u.name.presence || u.email } }
          }
        end
        {
          id: h.id,
          name: h.name,
          usage: h.usage_count,
          is_default: h.is_default?,
          roles: roles
        }
      end
    end

    def wizard_assignments_complete?(hierarchy, assignments)
      return false if hierarchy.blank?

      hierarchy.hierarchy_roles.all? { |hr| assignments[hr.review_role_id.to_s].present? }
    end
  end
end
