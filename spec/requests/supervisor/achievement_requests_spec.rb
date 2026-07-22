require "rails_helper"

RSpec.describe "Supervisor review actions", type: :request do
  let(:supervisor)   { create(:user, :faculty) }
  let(:sub_division) { create(:sub_division, supervisor: supervisor) }
  let(:category)     { create(:category, sub_division: sub_division) }
  let(:request_record) { create(:achievement_request, category: category) }

  before { sign_in supervisor }

  describe "PATCH approve" do
    it "forwards to the dean and logs history" do
      patch approve_supervisor_achievement_request_path(request_record)

      expect(response).to redirect_to(supervisor_root_path)
      expect(request_record.reload.status).to eq("supervisor_approved")

      history = request_record.req_histories.sole
      expect(history.action).to eq("supervisor_approve")
      expect(history.actor).to eq(supervisor)
      expect(history.from_status).to eq("submitted")
      expect(history.to_status).to eq("supervisor_approved")
    end

    it "blocks faculty who don't supervise that sub-division" do
      sign_in create(:user, :faculty), scope: :user

      patch approve_supervisor_achievement_request_path(request_record)

      expect(response).to redirect_to(root_path)
      expect(request_record.reload.status).to eq("submitted")
    end

    it "refuses requests that are not submitted" do
      request_record.update!(status: :supervisor_approved)

      patch approve_supervisor_achievement_request_path(request_record)

      expect(response).to redirect_to(supervisor_root_path)
      expect(flash[:alert]).to eq("This request is no longer awaiting your review.")
    end
  end

  describe "PATCH revert" do
    it "reverts with a comment and optional reason template" do
      template = create(:reason_template, message_text: "Proof is unreadable.")

      patch revert_supervisor_achievement_request_path(request_record),
            params: { comment: "Proof is unreadable, please re-upload.", reason_template_id: template.id }

      expect(request_record.reload.status).to eq("supervisor_reverted")

      history = request_record.req_histories.sole
      expect(history.action).to eq("supervisor_revert")
      expect(history.comment).to eq("Proof is unreadable, please re-upload.")
      expect(history.reason_template).to eq(template)
    end

    it "requires a comment" do
      patch revert_supervisor_achievement_request_path(request_record), params: { comment: "  " }

      expect(response).to redirect_to(supervisor_achievement_request_path(request_record))
      expect(flash[:alert]).to eq("A message to the student is required.")
      expect(request_record.reload.status).to eq("submitted")
      expect(request_record.req_histories.count).to eq(0)
    end
  end

  describe "PATCH reject" do
    it "rejects terminally with a comment" do
      patch reject_supervisor_achievement_request_path(request_record),
            params: { comment: "Fraudulent claim." }

      expect(request_record.reload.status).to eq("rejected")

      history = request_record.req_histories.sole
      expect(history.action).to eq("supervisor_reject")
      expect(history.comment).to eq("Fraudulent claim.")
    end
  end

  describe "GET show" do
    it "renders for the assigned supervisor" do
      get supervisor_achievement_request_path(request_record)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(request_record.title)
    end

    it "denies other supervisors" do
      other = create(:sub_division).supervisor
      sign_in other, scope: :user

      get supervisor_achievement_request_path(request_record)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST create (Path B)" do
    let(:student_profile) { create(:student) }

    let(:valid_params) do
      { achievement_request: {
        student_id: student_profile.id,
        category_id: category.id,
        title: "Unauthorized absence",
        description: "Missed three lab sessions without notice",
        proofs: [ fixture_file_upload("proof.png", "image/png") ]
      } }
    end

    it "creates the request at supervisor_approved with the supervisor as actor" do
      expect {
        post supervisor_achievement_requests_path, params: valid_params
      }.to change(AchievementRequest, :count).by(1)

      request = AchievementRequest.last
      expect(request.status).to eq("supervisor_approved")
      expect(request.student).to eq(student_profile)

      history = request.req_histories.sole
      expect(history.action).to eq("supervisor_initiate")
      expect(history.actor).to eq(supervisor)
    end

    it "rejects categories outside the supervisor's sub-divisions" do
      foreign_category = create(:category)
      params = valid_params.deep_merge(achievement_request: { category_id: foreign_category.id })

      expect {
        post supervisor_achievement_requests_path, params: params
      }.not_to change(AchievementRequest, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("must be under one of your sub-divisions")
    end

    it "re-renders with errors when the form is submitted blank" do
      sub_division # materialize the supervisor assignment

      expect {
        post supervisor_achievement_requests_path, params: { achievement_request: {
          student_id: "", category_id: "", title: "", description: "", proofs: [ "" ]
        } }
      }.not_to change(AchievementRequest, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("can&#39;t be blank")
    end

    it "re-renders on validation failure" do
      invalid = valid_params.deep_merge(achievement_request: { proofs: [] })

      expect {
        post supervisor_achievement_requests_path, params: invalid
      }.not_to change(AchievementRequest, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET new (Path B)" do
    let(:student_profile) { create(:student, usn: "1SC24ME001", user: create(:user, name: "Arjun Menon")) }

    before { sub_division }

    it "locks the student field when student_id is prefilled" do
      get new_supervisor_achievement_request_path(achievement_request: { student_id: student_profile.id })

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("1SC24ME001")
      expect(response.body).to include("Arjun Menon")
      expect(response.body).to include('name="achievement_request[student_id]"')
      expect(response.body).to include('type="hidden"')
      expect(response.body).not_to include("Select a student")
    end

    it "keeps the student dropdown when no student_id is given" do
      get new_supervisor_achievement_request_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Select a student")
    end
  end
end
