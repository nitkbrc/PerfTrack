module Admin
  class DivisionsController < BaseController
    def index
      authorize Division
      @divisions = Division.includes(:dean).order(:name)
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

    private

    def division_params
      params.expect(division: [ :name, :div_type, :dean_user_id ])
    end
  end
end
