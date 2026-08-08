module Admin
  class ReviewRolesController < BaseController
    def index
      authorize ReviewRole
      ReviewRole.ensure_system_roles!
      @division_roles = ReviewRole.scope_division.order(:name)
      @sub_division_roles = ReviewRole.scope_sub_division.order(:name)
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
        redirect_to admin_review_roles_path, notice: "Review role updated.", status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def bulk_save
      authorize ReviewRole
      updates = bulk_raiseable_params

      ReviewRole.transaction do
        updates.each do |id, attrs|
          role = ReviewRole.find(id)
          next unless role.scope_sub_division?

          role.update!(
            raiseable_on_behalf_eligible: ActiveModel::Type::Boolean.new.cast(
              attrs[:raiseable_on_behalf_eligible]
            )
          )
        end
      end

      redirect_to admin_review_roles_path, notice: "Raise-on-behalf settings saved.", status: :see_other
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

    def bulk_raiseable_params
      raw = params.fetch(:roles, {})
      return {} unless raw.respond_to?(:to_unsafe_h)

      raw.to_unsafe_h.each_with_object({}) do |(id, attrs), permitted|
        next unless id.to_s.match?(/\A\d+\z/)
        next unless attrs.is_a?(Hash)

        permitted[id.to_i] = {
          raiseable_on_behalf_eligible: attrs["raiseable_on_behalf_eligible"] || attrs[:raiseable_on_behalf_eligible]
        }
      end
    end
  end
end
