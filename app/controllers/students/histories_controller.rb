module Students
  class HistoriesController < BaseController
    def index
      authorize AchievementRequest, :index?

      scope = policy_scope(AchievementRequest)
                .where(status: %i[approved rejected])
                .includes(category: { sub_division: :division }, req_histories: :actor)
                .order(updated_at: :desc)

      approved = scope.select(&:approved?)
      rejected = scope.select(&:rejected?)

      @accepted_positive = approved.select { |r| r.points_awarded.to_i.positive? }
      @accepted_negative = approved.select { |r| r.points_awarded.to_i.negative? }
      @rejected_positive = rejected.select(&:display_polarity_positive?)
      @rejected_negative = rejected.reject(&:display_polarity_positive?)
    end
  end
end
