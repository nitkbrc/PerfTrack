module Admin
  class SubDivisionsController < BaseController
    def index
      authorize SubDivision
      @sub_divisions = SubDivision.includes(:division, :supervisor).order(:name)
    end

    def new
      @sub_division = authorize SubDivision.new
    end

    def create
      @sub_division = authorize SubDivision.new(sub_division_params)
      if @sub_division.save
        redirect_to admin_sub_divisions_path, notice: "Sub-division created."
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
        redirect_to admin_sub_divisions_path, notice: "Sub-division updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      sub_division = authorize SubDivision.find(params[:id])
      sub_division.destroy!
      redirect_to admin_sub_divisions_path, notice: "Sub-division deleted."
    end

    private

    def sub_division_params
      params.expect(sub_division: [ :name, :division_id, :supervisor_user_id ])
    end
  end
end
