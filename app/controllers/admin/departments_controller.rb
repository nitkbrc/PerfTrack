module Admin
  class DepartmentsController < BaseController
    def index
      authorize Department
      @departments = Department.order(:name)
    end

    def new
      @department = authorize Department.new
    end

    def create
      @department = authorize Department.new(department_params)
      if @department.save
        redirect_to admin_departments_path, notice: "Department created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @department = authorize Department.find(params[:id])
    end

    def update
      @department = authorize Department.find(params[:id])
      if @department.update(department_params)
        redirect_to admin_departments_path, notice: "Department updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      department = authorize Department.find(params[:id])
      department.destroy!
      redirect_to admin_departments_path, notice: "Department deleted."
    end

    private

    def department_params
      params.expect(department: [ :name ])
    end
  end
end
