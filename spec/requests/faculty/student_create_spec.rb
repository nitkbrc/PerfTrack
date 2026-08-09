require "rails_helper"

RSpec.describe "Faculty student create and import", type: :request do
  let(:faculty) { create(:user, :faculty, name: "Prof. Allowed") }
  let!(:department) { create(:department, name: "Computer Science") }

  def enable_dean_create!
    ReviewRole.ensure_system_roles!
    ReviewRole.dean.update!(can_create_students: true)
    create(:division, dean: faculty)
  end

  describe "without permission" do
    before { sign_in faculty }

    it "hides create actions on the students index" do
      get faculty_students_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Add student")
      expect(response.body).not_to include("Import CSV")
    end

    it "forbids the new student form" do
      get new_faculty_student_path

      expect(response).to redirect_to(root_path)
    end

    it "forbids CSV import" do
      get new_faculty_student_import_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "with an enabled review role assignment" do
    before do
      enable_dean_create!
      sign_in faculty
    end

    it "shows create actions on the students index" do
      get faculty_students_path

      expect(response.body).to include("Add student")
      expect(response.body).to include(new_faculty_student_path)
      expect(response.body).to include("Import CSV")
      expect(response.body).to include(new_faculty_student_import_path)
    end

    it "creates a student with a USN temporary password and placeholder photo" do
      expect {
        post faculty_students_path, params: {
          user: {
            name: "New Student",
            email: "newstud@college.edu",
            phone: "9111000099",
            address: "Hostel Block A",
            student_profile_attributes: {
              usn: "1XX22CS777",
              department_id: department.id,
              sem: 3
            }
          }
        }
      }.to change(User, :count).by(1).and change(Student, :count).by(1)

      user = User.find_by!(email: "newstud@college.edu")
      expect(user.role).to eq("student")
      expect(user.password_change_required).to be(true)
      expect(user.valid_password?("1XX22CS7771XX22CS777")).to be(true)
      expect(user.photo).to be_attached
      expect(user.photo.filename.to_s).to eq("placeholder.png")
      expect(response).to redirect_to(faculty_student_path(user.student_profile))
    end

    it "rejects creating a student with a taken phone number" do
      create(:user, phone: "9111000099")

      expect {
        post faculty_students_path, params: {
          user: {
            name: "Dupe Phone",
            email: "dupephone@college.edu",
            phone: "9111-000-099",
            address: "Somewhere",
            student_profile_attributes: {
              usn: "1XX22CS778",
              department_id: department.id,
              sem: 2
            }
          }
        }
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("has already been taken")
    end

    it "imports students from CSV and skips colliding phones" do
      create(:user, phone: "9876543210")

      csv = <<~CSV
        name,email,phone,address,usn,department,sem
        Good Student,good@college.edu,9876543290,Campus Road,1XX22CS010,Computer Science,2
        Phone Taken,taken@college.edu,9876543210,Campus Road,1XX22CS011,Computer Science,2
      CSV
      file = Rack::Test::UploadedFile.new(StringIO.new(csv), "text/csv", original_filename: "students.csv")

      post faculty_student_imports_path, params: { file: file }

      expect(response).to have_http_status(:ok)
      expect(User.find_by(email: "good@college.edu")).to be_present
      expect(User.find_by(email: "taken@college.edu")).to be_nil
      expect(response.body).to include("Phone has already been taken")
      expect(User.find_by(email: "good@college.edu").role).to eq("student")
    end

    it "serves a student-only CSV template" do
      get template_faculty_student_imports_path

      expect(response.headers["Content-Type"]).to include("text/csv")
      expect(response.body).to include("name,email,phone,address,usn,department,sem")
      expect(response.body).not_to include(",role,")
    end
  end
end
