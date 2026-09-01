require "rails_helper"

RSpec.describe "Student history", type: :request do
  let(:profile) { create(:student) }
  let(:supervisor) { create(:user, :faculty) }

  def proof
    fixture_file_upload("proof.png", "image/png")
  end

  def submit_and_approve!(student:, category:, title:, supervisor_user:, dean_user:)
    request = AchievementRequest.submit!(
      student: student,
      actor: student.user,
      attrs: { category: category, title: title, description: "Details", proofs: [ proof ] }
    )
    request.advance!(actor: supervisor_user)
    request.advance!(actor: dean_user)
    request
  end

  before { sign_in profile.user }

  describe "GET /student/history" do
    it "groups the student's decided requests and excludes other students" do
      positive_division = create(:division, div_type: "positive")
      positive_sub = create(:sub_division, division: positive_division, supervisor: supervisor)
      positive_category = create(:category, sub_division: positive_sub, name: "Hackathon", points: 25)
      dean = positive_division.dean

      path_a = submit_and_approve!(
        student: profile,
        category: positive_category,
        title: "Path A win",
        supervisor_user: supervisor,
        dean_user: dean
      )

      negative_division = create(:division, :negative)
      negative_sub = create(:sub_division, division: negative_division, supervisor: supervisor)
      negative_category = create(:category, sub_division: negative_sub, name: "Absence", points: 10)
      negative_dean = negative_division.dean

      path_b = AchievementRequest.supervisor_initiate!(
        student: profile,
        actor: supervisor,
        attrs: {
          category: negative_category,
          title: "Path B conduct",
          description: "Raised by supervisor",
          proofs: [ proof ]
        }
      )
      path_b.advance!(actor: negative_dean)

      rejected_division = create(:division, div_type: "positive")
      rejected_sub = create(:sub_division, division: rejected_division, supervisor: supervisor)
      rejected_category = create(:category, sub_division: rejected_sub, name: "Sports", points: 5)
      rejected_dean = rejected_division.dean
      rejected = AchievementRequest.submit!(
        student: profile,
        actor: profile.user,
        attrs: {
          category: rejected_category,
          title: "Rejected attempt",
          description: "Not enough proof",
          proofs: [ proof ]
        }
      )
      rejected.advance!(actor: supervisor)
      rejected.reject!(actor: rejected_dean, comment: "Insufficient evidence")

      other_student = create(:student)
      other_category = create(:category)
      create(:achievement_request, :approved, student: other_student, category: other_category,
             title: "Someone else's win")

      get student_history_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Request history")
      expect(response.body).to include("Path A win")
      expect(response.body).to include("Path B conduct")
      expect(response.body).to include("Rejected attempt")
      expect(response.body).to include("Raised on your behalf")
      expect(response.body).to include("+25 pts")
      expect(response.body).to include("-10 pts")
      expect(response.body).not_to include("Someone else's win")

      accepted_positive = response.body.split("Accepted").second.split("Rejected").first
      accepted_negative = accepted_positive.split("Negative").last
      rejected_section = response.body.split("Rejected").last

      expect(accepted_positive).to include("Path A win")
      expect(accepted_positive).not_to include("Path B conduct")
      expect(accepted_negative).to include("Path B conduct")
      expect(rejected_section).to include("Rejected attempt")
    end

    it "includes History in student navigation" do
      get student_history_path

      expect(response.body).to include("History")
    end

    it "denies faculty" do
      sign_out profile.user
      sign_in create(:user, :faculty)

      get student_history_path

      expect(response).to redirect_to(root_path)
    end
  end
end
