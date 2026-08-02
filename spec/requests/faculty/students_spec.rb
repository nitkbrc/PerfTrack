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
    create(:achievement_request, :approved, student: student, category: category,
           title: "#{category.name} entry", points_awarded: points)
  end

  before { sign_in faculty }

  describe "GET /faculty/students" do
    it "lists every student with name, department, overall score, and photo markup" do
      approve!(positive_category, 30)
      other = create(:student, user: create(:user, name: "Vikram Singh"))

      get faculty_students_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Asha Kumar")
      expect(response.body).to include("Computer Science")
      expect(response.body).to include(student.overall_score.to_s)
      expect(response.body).to include("Vikram Singh")
      expect(response.body).to include(other.usn)
      expect(response.body).to include("scats-list-photo")
      expect(response.body).to include("rounded-full")
    end

    it "filters students by department" do
      cse = create(:department, name: "CSE")
      ece = create(:department, name: "ECE")
      matched = create(:student, department: cse, user: create(:user, name: "CSE Student"))
      other = create(:student, department: ece, user: create(:user, name: "ECE Student"))

      get faculty_students_path, params: { department_id: cse.id }

      expect(response.body).to include("CSE Student")
      expect(response.body).to include(matched.usn)
      expect(response.body).not_to include("ECE Student")
      expect(response.body).not_to include(other.usn)
    end

    it "filters students by semester" do
      sem3 = create(:student, sem: 3, user: create(:user, name: "Sem Three"))
      sem5 = create(:student, sem: 5, user: create(:user, name: "Sem Five"))

      get faculty_students_path, params: { sem: 3 }

      expect(response.body).to include("Sem Three")
      expect(response.body).to include(sem3.usn)
      expect(response.body).not_to include("Sem Five")
      expect(response.body).not_to include(sem5.usn)
    end

    it "filters students by name or USN search" do
      by_name = create(:student, usn: "1XX22CS100", user: create(:user, name: "Priya Nair"))
      by_usn = create(:student, usn: "1XX22EC200", user: create(:user, name: "Other Student"))
      unmatched = create(:student, usn: "1XX22ME300", user: create(:user, name: "Unmatched"))

      get faculty_students_path, params: { q: "Priya" }
      expect(response.body).to include("Priya Nair")
      expect(response.body).to include(by_name.usn)
      expect(response.body).not_to include(by_usn.usn)
      expect(response.body).not_to include("Unmatched")

      get faculty_students_path, params: { q: "1XX22EC200" }
      expect(response.body).to include("Other Student")
      expect(response.body).to include(by_usn.usn)
      expect(response.body).not_to include("Priya Nair")
      expect(response.body).not_to include(unmatched.usn)
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
      expect(response.body).to include("Positive points")
      expect(response.body).to include("Overall score")
      expect(response.body).to include(student.overall_score.to_s)
      # Only approved requests contribute to the breakdown.
      expect(response.body).not_to include("Still pending")
    end

    it "shows photo, phone, and address" do
      student.user.update!(phone: "9988776655", address: "42 Campus Road")
      get faculty_student_path(student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("9988776655")
      expect(response.body).to include("42 Campus Road")
      expect(response.body).to include("rounded-full")
    end

    it "is denied to students" do
      sign_in create(:user)

      get faculty_student_path(student)

      expect(response).to redirect_to(root_path)
    end

    it "shows Raise a request for supervisors, prefilled for that student" do
      supervisor = create(:user, :faculty)
      create(:sub_division, supervisor: supervisor)
      sign_in supervisor

      get faculty_student_path(student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Raise a request")
      expect(response.body).to include(
        new_supervisor_achievement_request_path(achievement_request: { student_id: student.id })
      )
    end

    it "does not show Raise a request for faculty who are not supervisors" do
      get faculty_student_path(student)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Raise a request")
    end
  end
end
