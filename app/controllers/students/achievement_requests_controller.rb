module Students
  class AchievementRequestsController < BaseController
    before_action :load_division_tree, only: [ :new, :create ]

    def new
      @achievement_request = authorize AchievementRequest.new
    end

    def create
      authorize AchievementRequest
      AchievementRequest.submit!(student: current_student, actor: current_user, attrs: request_params)
      redirect_to student_root_path, notice: "Your request has been submitted."
    rescue ActiveRecord::RecordInvalid => e
      @achievement_request = e.record.is_a?(AchievementRequest) ? e.record : AchievementRequest.new(request_params)
      render :new, status: :unprocessable_content
    end

    def show
      @achievement_request = authorize AchievementRequest.find(params[:id])
      @histories = @achievement_request.req_histories.includes(:actor).order(:created_at)
    end

    private

    def request_params
      params.expect(achievement_request: [ :category_id, :title, :description, { proofs: [] } ])
    end

    # Serialized once into the form so the cascading selects work without
    # network round-trips.
    def load_division_tree
      @division_tree = Division.includes(sub_divisions: :categories).order(:name).map do |division|
        {
          id: division.id,
          name: division.name,
          divType: division.div_type,
          subDivisions: division.sub_divisions.sort_by { |sd| sd.name.to_s }.map do |sub_division|
            {
              id: sub_division.id,
              name: sub_division.name,
              categories: sub_division.categories.sort_by { |c| c.name.to_s }.map do |category|
                { id: category.id, name: category.name, points: category.points }
              end
            }
          end
        }
      end
    end
  end
end
