module Admin
  class SubDivisionsController < BaseController
    def index
      authorize SubDivision
      @show_archived = params[:archived].present?
      scope = @show_archived ? SubDivision.archived : SubDivision.active
      @sub_divisions = scope.includes(:division, :supervisor).order(:name)
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
    end

    def create
      @sub_division = authorize SubDivision.new(sub_division_params)
      if @sub_division.save
        redirect_to admin_division_path(@sub_division.division), notice: "Sub-division created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @sub_division = authorize SubDivision.find(params[:id])
    end

    def update
      @sub_division = authorize SubDivision.find(params[:id])
      if @sub_division.update(sub_division_params)
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
      sub_division.archive!
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
      params.expect(sub_division: [ :name, :division_id, :supervisor_user_id ])
    end
  end
end
