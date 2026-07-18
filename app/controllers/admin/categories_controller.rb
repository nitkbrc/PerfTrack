module Admin
  class CategoriesController < BaseController
    def index
      authorize Category
      @categories = Category.includes(sub_division: :division).order(:name)
    end

    def new
      @category = authorize Category.new
    end

    def create
      @category = authorize Category.new(category_params)
      if @category.save
        redirect_to admin_categories_path, notice: "Category created."
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
        redirect_to admin_categories_path, notice: "Category updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      category = authorize Category.find(params[:id])
      category.destroy!
      redirect_to admin_categories_path, notice: "Category deleted."
    end

    private

    def category_params
      params.expect(category: [ :name, :sub_division_id, :points ])
    end
  end
end
