require "rails_helper"

RSpec.describe "Dean decision flow", type: :request do
  let(:dean)         { create(:user, :faculty) }
  let(:division)     { create(:division, dean: dean, div_type: "positive") }
  let(:sub_division) { create(:sub_division, division: division) }
  let(:category)     { create(:category, sub_division: sub_division, points: 20) }
  let(:request_record) do
    create(:achievement_request, category: category, at_step: :dean)
  end

  before { sign_in dean }

  describe "GET /dean/queue" do
    it "shows only in-review requests at the dean step in the dean's division" do
      request_record.update!(title: "Forwarded to me")
      create(:achievement_request, at_step: :dean, title: "Other division")
      create(:achievement_request, category: category, title: "Still with supervisor")

      get dean_queue_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Forwarded to me")
      expect(response.body).not_to include("Other division")
      expect(response.body).not_to include("Still with supervisor")
    end

    it "denies non-dean faculty, students, and admins" do
      [ create(:user, :faculty), create(:user), create(:user, :admin) ].each do |user|
        sign_in user
        get dean_queue_path

        expect(response).to redirect_to(root_path)
        sign_out user
      end
    end
  end

  describe "PATCH approve" do
    it "snapshots signed points and logs history" do
      patch approve_dean_achievement_request_path(request_record)

      expect(response).to redirect_to(dean_queue_path)
      request_record.reload
      expect(request_record.status).to eq("approved")
      expect(request_record.points_awarded).to eq(20)

      history = request_record.req_histories.sole
      expect(history.action).to eq("approve")
      expect(history.actor).to eq(dean)
    end

    it "enqueues the notification job for the student" do
      expect { patch approve_dean_achievement_request_path(request_record) }
        .to have_enqueued_job(DeanApprovalNotificationJob).with(request_record.id)
    end

    it "snapshots negative points for a negative division" do
      division.update!(div_type: "negative")

      patch approve_dean_achievement_request_path(request_record)

      expect(request_record.reload.points_awarded).to eq(-20)
    end

    it "blocks deans of other divisions" do
      other_dean = create(:division).dean
      sign_in other_dean

      patch approve_dean_achievement_request_path(request_record)

      expect(response).to redirect_to(dean_queue_path)
      expect(flash[:alert]).to eq("This request is no longer awaiting your decision.")
      expect(request_record.reload.status).to eq("in_review")
    end

    it "refuses requests not at the dean step" do
      request_record.update_columns(current_review_role_id: ReviewRole.supervisor.id)

      patch approve_dean_achievement_request_path(request_record)

      expect(response).to redirect_to(dean_queue_path)
      expect(flash[:alert]).to eq("This request is no longer awaiting your decision.")
    end
  end

  describe "PATCH revert" do
    it "sends back with a shared canned template message (ignores client comment)" do
      template = create(:reason_template, :shared,
                        action: "revert",
                        message_text: "Please attach the certificate.")

      patch revert_dean_achievement_request_path(request_record),
            params: { comment: "Need the original certificate.", reason_template_id: template.id }

      request_record.reload
      expect(request_record.status).to eq("in_review")
      expect(request_record.current_reviewer).to eq(sub_division.supervisor)
      expect(request_record.points_awarded).to be_nil

      history = request_record.req_histories.sole
      expect(history.action).to eq("revert")
      expect(history.comment).to eq("Please attach the certificate.")
      expect(history.reason_template).to eq(template)
    end

    it "requires choosing a reason" do
      patch revert_dean_achievement_request_path(request_record), params: { comment: "" }

      expect(response).to redirect_to(dean_achievement_request_path(request_record))
      expect(flash[:alert]).to eq("Choose a reason.")
      expect(request_record.reload.status).to eq("in_review")
    end
  end

  describe "PATCH reject" do
    it "rejects terminally with Other free-text and no points" do
      patch reject_dean_achievement_request_path(request_record),
            params: { comment: "Insufficient evidence.", reason_template_id: "other" }

      request_record.reload
      expect(request_record.status).to eq("rejected")
      expect(request_record.points_awarded).to be_nil
      history = request_record.req_histories.sole
      expect(history.action).to eq("reject")
      expect(history.comment).to eq("Insufficient evidence.")
      expect(history.reason_template).to be_nil
    end
  end

  describe "GET show" do
    it "renders for the division's dean" do
      get dean_achievement_request_path(request_record)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(request_record.title)
    end
  end
end
