module Admin
  class CategoriesController < BaseController
    def index
      authorize Category
      @show_archived = params[:archived].present?
      scope = @show_archived ? Category.archived : Category.active
      @categories = scope.includes(sub_division: :division).order(:name)
      @archived_count = Category.archived.count
    end

    def new
      @category = authorize Category.new(sub_division_id: params[:sub_division_id])
    end

    def create
      @category = authorize Category.new(category_params)
      if @category.save
        redirect_to admin_sub_division_path(@category.sub_division), notice: "Category created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @category = authorize Category.find(params[:id])
    end

    def update
      @category = authorize Category.find(params[:id])
      if @category.update(category_params)
        redirect_to admin_sub_division_path(@category.sub_division), notice: "Category updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      category = authorize Category.find(params[:id])
      sub_division = category.sub_division
      category.destroy!
      redirect_to admin_sub_division_path(sub_division), notice: "Category deleted."
    end

    def archive
      category = authorize Category.find(params[:id])
      category.archive!
      redirect_to admin_sub_division_path(category.sub_division), notice: "#{category.name} archived."
    end

    def restore
      category = authorize Category.find(params[:id])
      if category.sub_division.archived?
        redirect_to admin_sub_division_path(category.sub_division, archived: 1),
                    alert: "Restore the #{category.sub_division.name} sub-division first."
      else
        category.restore!
        redirect_to admin_sub_division_path(category.sub_division, archived: 1), notice: "#{category.name} restored."
      end
    end

    private

    def category_params
      params.expect(category: [ :name, :sub_division_id, :points ])
    end
  end
end
