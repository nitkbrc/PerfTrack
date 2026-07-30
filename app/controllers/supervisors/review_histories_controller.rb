module Supervisors
  class ReviewHistoriesController < BaseController
    def index
      authorize AchievementRequest, :initiate?
      @histories = own_review_histories
                     .includes(
                       request_version: { category: { sub_division: :division } },
                       achievement_request: :student
                     )
                     .order(created_at: :desc)
    end

    def show
      @history = own_review_histories
                   .includes(
                     request_version: [
                       { category: { sub_division: :division } },
                       { proofs_attachments: :blob },
                       { req_histories: :actor }
                     ],
                     achievement_request: [ :student, { request_versions: { req_histories: :actor } } ]
                   )
                   .find(params[:id])
      authorize @history.achievement_request, :show?

      @version = @history.request_version
      @request_record = @history.achievement_request
      @versions = @request_record.request_versions.sort_by(&:version_number)
      @version_index = @versions.index { |v| v.id == @version.id } || 0
    end

    private

    def own_review_histories
      ReqHistory.review_actions.by_actor(current_user)
    end
  end
end
