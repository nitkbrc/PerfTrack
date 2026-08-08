module Admin
  class DivisionsController < BaseController
    def index
      authorize Division
      @show_archived = params[:archived].present?
      scope = @show_archived ? Division.archived : Division.active
      @divisions = scope.includes(role_assignments: :user).order(:name)
      @archived_count = Division.archived.count
    end

    def show
      @division = authorize Division.find(params[:id])
      @show_archived = params[:archived].present?
      scope = @show_archived ? @division.sub_divisions.archived : @division.sub_divisions.active
      @sub_divisions = scope.includes(:division, role_assignments: :user).order(:name)
      @archived_count = @division.sub_divisions.archived.count
    end

    def new
      @division = authorize Division.new
      load_wizard_collections
    end

    def create
      @division = authorize Division.new(division_params)
      load_wizard_collections

      assignments = params[:assignments]
      assignments = assignments.respond_to?(:permit!) ? assignments.permit!.to_h : {}
      unless wizard_assignments_complete?(@division.hierarchy, assignments)
        @division.errors.add(:base, "Assign a person to every role in the hierarchy")
        render :new, status: :unprocessable_entity
        return
      end

      ActiveRecord::Base.transaction do
        @division.save!
        @division.hierarchy.hierarchy_roles.each do |hr|
          user_id = assignments[hr.review_role_id.to_s]
          RoleAssignment.create!(
            user_id: user_id,
            review_role: hr.review_role,
            division: @division
          )
        end
      end

      redirect_to admin_divisions_path, notice: "Division created."
    rescue ActiveRecord::RecordInvalid => e
      @division = e.record if e.record.is_a?(Division)
      @division ||= Division.new(division_params)
      @division.errors.merge!(e.record.errors) unless e.record.is_a?(Division)
      load_wizard_collections
      render :new, status: :unprocessable_entity
    end

    def edit
      @division = authorize Division.find(params[:id])
    end

    def update
      @division = authorize Division.find(params[:id])
      if @division.update(division_params.slice(:name, :div_type))
        redirect_to admin_divisions_path, notice: "Division updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      division = authorize Division.find(params[:id])
      division.destroy!
      redirect_to admin_divisions_path, notice: "Division deleted."
    end

    def archive
      division = authorize Division.find(params[:id])
      division.archive!(actor: current_user)
      redirect_to admin_divisions_path,
                  notice: "#{division.name} archived, along with its sub-divisions and categories."
    end

    def restore
      division = authorize Division.find(params[:id])
      division.restore!
      redirect_to admin_divisions_path(archived: 1), notice: "#{division.name} restored."
    end

    private

    def division_params
      params.expect(division: [ :name, :div_type, :hierarchy_id ])
    end

    def load_wizard_collections
      Hierarchy.ensure_defaults!
      @hierarchies = Hierarchy.scope_division.includes(hierarchy_roles: :review_role).order(:name)
      @hierarchy_options = @hierarchies.map { |h| hierarchy_option_payload(h, :division) }
    end

    def hierarchy_option_payload(hierarchy, kind)
      roles = hierarchy.hierarchy_roles.includes(:review_role).map do |hr|
        eligible =
          if kind == :division
            User.eligible_for_role(hr.review_role).order(:name)
          else
            User.eligible_for_role(hr.review_role).order(:name)
          end
        {
          id: hr.review_role_id,
          name: hr.review_role.name,
          eligible: eligible.map { |u| { id: u.id, label: u.name.presence || u.email } }
        }
      end
      {
        id: hierarchy.id,
        name: hierarchy.name,
        usage: hierarchy.usage_count,
        is_default: hierarchy.is_default?,
        roles: roles
      }
    end

    def wizard_assignments_complete?(hierarchy, assignments)
      return false if hierarchy.blank?

      hierarchy.hierarchy_roles.all? { |hr| assignments[hr.review_role_id.to_s].present? }
    end
  end
end
