module Admin
  class ReviewRolesController < BaseController
    def index
      authorize ReviewRole
      ReviewRole.ensure_system_roles!
      @review_roles = ReviewRole.order(:scope, :name)
    end

    def new
      @review_role = authorize ReviewRole.new(scope: "sub_division")
    end

    def create
      @review_role = authorize ReviewRole.new(review_role_params.merge(system_role: false))
      if @review_role.save
        redirect_to admin_review_roles_path, notice: "Review role created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @review_role = authorize ReviewRole.find(params[:id])
    end

    def update
      @review_role = authorize ReviewRole.find(params[:id])
      attrs = review_role_params
      attrs = attrs.except(:scope) if @review_role.system_role?
      if @review_role.update(attrs)
        redirect_to admin_review_roles_path, notice: "Review role updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      review_role = authorize ReviewRole.find(params[:id])
      review_role.destroy!
      redirect_to admin_review_roles_path, notice: "Review role deleted."
    rescue ActiveRecord::RecordNotDestroyed
      redirect_to admin_review_roles_path, alert: review_role.errors.full_messages.to_sentence.presence || "Could not delete role."
    end

    private

    def review_role_params
      params.expect(review_role: [ :name, :scope, :raiseable_on_behalf_eligible ])
    end
  end
end
