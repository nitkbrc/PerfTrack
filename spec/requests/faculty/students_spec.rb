require "rails_helper"

RSpec.describe "Faculty students directory", type: :request do
  # Deliberately a faculty member with no supervisor/dean assignments —
  # the directory is open to every faculty user.
  let(:faculty) { create(:user, :faculty, name: "Prof. Rao") }
  let(:student) do
    create(:student, usn: "1XX22CS001",
                     user: create(:user, name: "Asha Kumar"),
                     department: create(:department, name: "Computer Science"))
  end

  let(:positive_category) { create(:category, sub_division: create(:sub_division), points: 30) }
  let(:negative_category) do
    create(:category, points: 10,
                      sub_division: create(:sub_division, division: create(:division, :negative)))
  end

  def approve!(category, points)
    create(:achievement_request, student: student, category: category, title: "#{category.name} entry")
      .update!(status: :dean_approved, points_awarded: points)
  end

  before { sign_in faculty }

  describe "GET /faculty/students" do
    it "lists every student with name, department and overall score" do
      approve!(positive_category, 30)
      other = create(:student, user: create(:user, name: "Vikram Singh"))

      get faculty_students_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Asha Kumar")
      expect(response.body).to include("Computer Science")
      expect(response.body).to include(student.overall_score.to_s)
      expect(response.body).to include("Vikram Singh")
      expect(response.body).to include(other.usn)
    end

    it "is denied to admins — student records are faculty-only" do
      sign_in create(:user, :admin)

      get faculty_students_path

      expect(response).to redirect_to(root_path)
    end

    it "is denied to students and signed-out users" do
      sign_in create(:user)
      get faculty_students_path
      expect(response).to redirect_to(root_path)

      sign_out :user
      get faculty_students_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /faculty/students/:id" do
    it "splits approved requests into positive and negative with totals" do
      approve!(positive_category, 30)
      approve!(negative_category, -10)
      create(:achievement_request, student: student, title: "Still pending")

      get faculty_student_path(student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Positive achievements")
      expect(response.body).to include("+30 pts")
      expect(response.body).to include("Negative records")
      expect(response.body).to include("-10 pts")
      expect(response.body).to include(student.overall_score.to_s)
      # Only dean-approved requests contribute to the breakdown.
      expect(response.body).not_to include("Still pending")
    end

    it "is denied to students" do
      sign_in create(:user)

      get faculty_student_path(student)

      expect(response).to redirect_to(root_path)
    end
  end
end
