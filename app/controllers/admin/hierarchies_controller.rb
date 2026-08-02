module Admin
  class HierarchiesController < BaseController
    def index
      authorize Division, :index?
      @divisions = Division.active
                           .includes(hierarchy_steps: :review_role, sub_divisions: { hierarchy_steps: :review_role })
                           .order(:name)
    end
  end
end
