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
    end

    def create
      @division = authorize Division.new(division_params)
      if @division.save
        redirect_to admin_divisions_path, notice: "Division created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @division = authorize Division.find(params[:id])
    end

    def update
      @division = authorize Division.find(params[:id])
      if @division.update(division_params)
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
      params.expect(division: [ :name, :div_type ])
    end
  end
end
