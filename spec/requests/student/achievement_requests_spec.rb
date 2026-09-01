require "rails_helper"

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe "Student achievement requests", type: :request do
  let(:profile)  { create(:student) }
  let(:category) { create(:category) }

  before { sign_in profile.user }

  describe "POST /student/achievement_requests" do
    let(:valid_params) do
      { achievement_request: {
        category_id: category.id,
        title: "State chess champion",
        description: "Won the state finals",
        proofs: [ fixture_file_upload("proof.png", "image/png") ]
      } }
    end

    it "creates an in-review request and its first history row in one transaction" do
      expect {
        post student_achievement_requests_path, params: valid_params
      }.to change(AchievementRequest, :count).by(1).and change(ReqHistory, :count).by(1)

      expect(response).to redirect_to(submitted_student_achievement_requests_path)

      request = AchievementRequest.last
      expect(request.status).to eq("in_review")
      expect(request.student).to eq(profile)
      expect(request.request_versions.count).to eq(1)
      expect(request.current_version.version_number).to eq(1)

      history = request.req_histories.sole
      expect(history.action).to eq("submit")
      expect(history.actor).to eq(profile.user)
      expect(history.to_status).to eq("in_review")
      expect(history.request_version).to eq(request.current_version)
    end

    it "creates no orphan history row when the request is invalid" do
      invalid = valid_params.deep_merge(achievement_request: { proofs: [] })

      expect {
        post student_achievement_requests_path, params: invalid
      }.to not_change(AchievementRequest, :count).and not_change(ReqHistory, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "re-renders the form on missing category" do
      invalid = valid_params.deep_merge(achievement_request: { category_id: "" })

      post student_achievement_requests_path, params: invalid

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Category must exist")
    end

    it "re-renders at the details step with category preserved on validation failure" do
      invalid = valid_params.deep_merge(achievement_request: { proofs: [] })

      post student_achievement_requests_path, params: invalid

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('data-raise-wizard-step-value="3"')
      expect(response.body).to include("Details &amp; Proof")
      expect(response.body).to include(%(value="#{category.id}"))
    end

    it "denies faculty" do
      sign_out profile.user
      sign_in create(:user, :faculty)

      post student_achievement_requests_path, params: valid_params

      expect(response).to redirect_to(root_path)
      expect(AchievementRequest.count).to eq(0)
    end
  end

  describe "GET /student/achievement_requests/:id" do
    let(:request_record) { create(:achievement_request, student: profile) }

    it "shows the student's own request with its history" do
      request_record.req_histories.create!(actor: profile.user, action: "submit", to_status: "in_review",
                                           request_version: request_record.current_version)

      get student_achievement_request_path(request_record)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(request_record.title)
      expect(response.body).to include("Submit")
    end

    it "denies another student's request" do
      other_request = create(:achievement_request)

      get student_achievement_request_path(other_request)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("You are not authorized to do that.")
    end
  end

  describe "GET /student/achievement_requests/new" do
    it "renders the form with the division tree" do
      division = create(:division, name: "Sports")
      create(:sub_division, division: division)

      get new_student_achievement_request_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sports")
    end

    it "renders the 3-step raise request wizard" do
      get new_student_achievement_request_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("What are you submitting?")
      expect(response.body).to include("Achievement submission")
      expect(response.body).to include("Conduct")
      expect(response.body).to include("Request Type")
      expect(response.body).to include("Choose Category")
      expect(response.body).to include("Details &amp; Proof")
      expect(response.body).to include('data-controller="raise-wizard"')
      expect(response.body).to include("pickerCards")
      expect(response.body).to include('data-raise-wizard-step-value="1"')
    end

    it "includes negative-division categories in the tree with divType negative (signed in JS)" do
      division = create(:division, :negative, name: "Conduct")
      sub_division = create(:sub_division, division: division, name: "Incidents")
      create(:category, sub_division: sub_division, name: "QA Conduct Incident", points: 15)

      get new_student_achievement_request_path

      expect(response).to have_http_status(:ok)
      doc = Nokogiri::HTML(response.body)
      tree_json = doc.at_css('[data-raise-wizard-tree-value]')&.[]("data-raise-wizard-tree-value")
      expect(tree_json).to be_present

      tree = JSON.parse(tree_json)
      conduct = tree.find { |d| d["name"] == "Conduct" }
      expect(conduct).to include("divType" => "negative")
      category = conduct.dig("subDivisions", 0, "categories", 0)
      expect(category).to include("name" => "QA Conduct Incident", "points" => 15)
      expect(tree_json).not_to include("+15")
    end
  end

  describe "GET /student/achievement_requests/submitted" do
    it "renders the confirmation page" do
      get submitted_student_achievement_requests_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Request Submitted")
    end

    it "shows the most recent request on the confirmation page" do
      req = create(:achievement_request, student: profile, title: "My chess title")

      get submitted_student_achievement_requests_path

      expect(response.body).to include("My chess title")
    end
  end
end
