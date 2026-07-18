require "rails_helper"

RSpec.describe "Dean decision flow", type: :request do
  let(:dean)         { create(:user, :faculty) }
  let(:division)     { create(:division, dean: dean, div_type: "positive") }
  let(:sub_division) { create(:sub_division, division: division) }
  let(:category)     { create(:category, sub_division: sub_division, points: 20) }
  let(:request_record) do
    create(:achievement_request, category: category).tap { |r| r.update!(status: :supervisor_approved) }
  end

  before { sign_in dean }

  describe "GET /dean (queue)" do
    it "shows only supervisor_approved requests in the dean's division" do
      request_record.update!(title: "Forwarded to me")
      create(:achievement_request, title: "Other division").tap { |r| r.update!(status: :supervisor_approved) }
      create(:achievement_request, category: category, title: "Still with supervisor")

      get dean_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Forwarded to me")
      expect(response.body).not_to include("Other division")
      expect(response.body).not_to include("Still with supervisor")
    end

    it "denies non-dean faculty, students, and admins" do
      [ create(:user, :faculty), create(:user), create(:user, :admin) ].each do |user|
        sign_in user
        get dean_root_path

        expect(response).to redirect_to(root_path)
        sign_out user
      end
    end
  end

  describe "PATCH approve" do
    it "snapshots signed points and logs history" do
      patch approve_dean_achievement_request_path(request_record)

      expect(response).to redirect_to(dean_root_path)
      request_record.reload
      expect(request_record.status).to eq("dean_approved")
      expect(request_record.points_awarded).to eq(20)

      history = request_record.req_histories.sole
      expect(history.action).to eq("dean_approve")
      expect(history.actor).to eq(dean)
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

      expect(response).to redirect_to(root_path)
      expect(request_record.reload.status).to eq("supervisor_approved")
    end

    it "refuses requests not at supervisor_approved" do
      request_record.update!(status: :submitted)

      patch approve_dean_achievement_request_path(request_record)

      expect(response).to redirect_to(dean_root_path)
      expect(flash[:alert]).to eq("This request is no longer awaiting your decision.")
    end
  end

  describe "PATCH revert" do
    it "sends back for clarification with a comment and template" do
      template = create(:reason_template, message_text: "Please attach the certificate.")

      patch revert_dean_achievement_request_path(request_record),
            params: { comment: "Need the original certificate.", reason_template_id: template.id }

      request_record.reload
      expect(request_record.status).to eq("dean_reverted")
      expect(request_record.points_awarded).to be_nil

      history = request_record.req_histories.sole
      expect(history.action).to eq("dean_revert")
      expect(history.comment).to eq("Need the original certificate.")
      expect(history.reason_template).to eq(template)
    end

    it "requires a comment" do
      patch revert_dean_achievement_request_path(request_record), params: { comment: "" }

      expect(response).to redirect_to(dean_achievement_request_path(request_record))
      expect(request_record.reload.status).to eq("supervisor_approved")
    end
  end

  describe "PATCH reject" do
    it "rejects terminally with no points" do
      patch reject_dean_achievement_request_path(request_record),
            params: { comment: "Insufficient evidence." }

      request_record.reload
      expect(request_record.status).to eq("rejected")
      expect(request_record.points_awarded).to be_nil
      expect(request_record.req_histories.sole.action).to eq("dean_reject")
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
