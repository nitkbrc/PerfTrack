require "rails_helper"

RSpec.describe "Supervisor review actions", type: :request do
  let(:supervisor)   { create(:user, :faculty) }
  let(:sub_division) { create(:sub_division, supervisor: supervisor) }
  let(:category)     { create(:category, sub_division: sub_division) }
  let(:request_record) { create(:achievement_request, category: category, at_step: :supervisor) }

  before { sign_in supervisor }

  describe "PATCH approve" do
    it "forwards to the dean and logs history" do
      patch approve_supervisor_achievement_request_path(request_record)

      expect(response).to redirect_to(supervisor_queue_path)
      expect(request_record.reload.status).to eq("in_review")
      expect(request_record.current_reviewer).to eq(sub_division.division.dean)

      history = request_record.req_histories.sole
      expect(history.action).to eq("advance")
      expect(history.actor).to eq(supervisor)
      expect(history.from_status).to eq("in_review")
      expect(history.to_status).to eq("in_review")
    end

    it "blocks faculty who don't supervise that sub-division" do
      sign_in create(:user, :faculty), scope: :user

      patch approve_supervisor_achievement_request_path(request_record)

      expect(response).to redirect_to(root_path)
      expect(request_record.reload.status).to eq("in_review")
    end

    it "refuses requests that are not awaiting the supervisor" do
      request_record.advance!(actor: supervisor)

      patch approve_supervisor_achievement_request_path(request_record)

      expect(response).to redirect_to(supervisor_queue_path)
      expect(flash[:alert]).to eq("This request is no longer awaiting your review.")
    end
  end

  describe "PATCH revert" do
    it "reverts with a shared canned template message (ignores client comment)" do
      template = create(:reason_template, :shared,
                        action: "revert",
                        message_text: "Proof is unreadable.")

      patch revert_supervisor_achievement_request_path(request_record),
            params: { comment: "tampered client text", reason_template_id: template.id }

      expect(request_record.reload.status).to eq("reverted")

      history = request_record.req_histories.sole
      expect(history.action).to eq("revert")
      expect(history.comment).to eq("Proof is unreadable.")
      expect(history.reason_template).to eq(template)
    end

    it "reverts with a division extra template" do
      template = create(:reason_template, :division_extra,
                        division: sub_division.division,
                        action: "revert",
                        message_text: "Sports-only proof note.")

      patch revert_supervisor_achievement_request_path(request_record),
            params: { reason_template_id: template.id }

      expect(request_record.reload.status).to eq("reverted")
      expect(request_record.req_histories.sole.comment).to eq("Sports-only proof note.")
    end

    it "rejects a suppressed shared template" do
      template = create(:reason_template, :shared, action: "revert", message_text: "Hidden here.")
      create(:reason_template_suppression, division: sub_division.division, reason_template: template)

      patch revert_supervisor_achievement_request_path(request_record),
            params: { reason_template_id: template.id }

      expect(response).to redirect_to(supervisor_achievement_request_path(request_record))
      expect(flash[:alert]).to eq("Choose a valid reason for this division.")
      expect(request_record.reload.status).to eq("in_review")
    end

    it "reverts with Other free-text" do
      patch revert_supervisor_achievement_request_path(request_record),
            params: { comment: "Please re-upload a clearer scan.", reason_template_id: "other" }

      expect(request_record.reload.status).to eq("reverted")
      history = request_record.req_histories.sole
      expect(history.comment).to eq("Please re-upload a clearer scan.")
      expect(history.reason_template).to be_nil
    end

    it "rejects a template from another division's extras" do
      other = create(:reason_template, :division_extra, action: "revert", message_text: "Wrong division reason.")

      patch revert_supervisor_achievement_request_path(request_record),
            params: { reason_template_id: other.id }

      expect(response).to redirect_to(supervisor_achievement_request_path(request_record))
      expect(flash[:alert]).to eq("Choose a valid reason for this division.")
      expect(request_record.reload.status).to eq("in_review")
    end

    it "requires Other comment text" do
      patch revert_supervisor_achievement_request_path(request_record),
            params: { comment: "  ", reason_template_id: "other" }

      expect(response).to redirect_to(supervisor_achievement_request_path(request_record))
      expect(flash[:alert]).to eq("A message is required when choosing Other.")
      expect(request_record.reload.status).to eq("in_review")
      expect(request_record.req_histories.count).to eq(0)
    end

    it "requires choosing a reason" do
      patch revert_supervisor_achievement_request_path(request_record), params: { comment: "ignored" }

      expect(response).to redirect_to(supervisor_achievement_request_path(request_record))
      expect(flash[:alert]).to eq("Choose a reason.")
      expect(request_record.reload.status).to eq("in_review")
    end
  end

  describe "PATCH reject" do
    it "rejects with a canned reject template" do
      template = create(:reason_template, :reject, :shared,
                        message_text: "Fraudulent claim.")

      patch reject_supervisor_achievement_request_path(request_record),
            params: { comment: "ignored", reason_template_id: template.id }

      expect(request_record.reload.status).to eq("rejected")

      history = request_record.req_histories.sole
      expect(history.action).to eq("reject")
      expect(history.comment).to eq("Fraudulent claim.")
      expect(history.reason_template).to eq(template)
    end

    it "rejects a revert template used for reject" do
      template = create(:reason_template, :shared,
                        action: "revert",
                        message_text: "Not for reject.")

      patch reject_supervisor_achievement_request_path(request_record),
            params: { reason_template_id: template.id }

      expect(response).to redirect_to(supervisor_achievement_request_path(request_record))
      expect(flash[:alert]).to eq("Choose a valid reason for this division.")
      expect(request_record.reload.status).to eq("in_review")
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

    it "creates the request in review at the dean step with the supervisor as actor" do
      expect {
        post supervisor_achievement_requests_path, params: valid_params
      }.to change(AchievementRequest, :count).by(1)

      request = AchievementRequest.last
      expect(request.status).to eq("in_review")
      expect(request.current_reviewer).to eq(sub_division.division.dean)
      expect(request.student).to eq(student_profile)
      expect(request.request_versions.count).to eq(1)

      history = request.req_histories.sole
      expect(history.action).to eq("supervisor_initiate")
      expect(history.actor).to eq(supervisor)
      expect(history.request_version).to eq(request.current_version)
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
      expect(response.body).to match(/proofs/i)
      expect(response.body).to include(%(value="#{student_profile.id}"))
      expect(response.body).to include("Unauthorized absence")
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
