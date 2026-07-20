require "rails_helper"

RSpec.describe "Admin user imports", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:department) { create(:department, name: "Computer Science") }

  before { sign_in admin }

  def upload(csv_content, extra_params = {})
    file = Rack::Test::UploadedFile.new(StringIO.new(csv_content), "text/csv", original_filename: "users.csv")
    post admin_user_imports_path, params: { file: file }.merge(extra_params)
  end

  it "imports students with a doubled-USN password that must be changed" do
    upload(<<~CSV)
      name,email,role,usn,department,sem
      Asha Kumar,asha@college.edu,student,1XX22CS001,Computer Science,3
    CSV

    expect(response).to have_http_status(:ok)
    user = User.find_by(email: "asha@college.edu")
    expect(user.student_profile.usn).to eq("1XX22CS001")
    expect(user.student_profile.sem).to eq(3)
    expect(user.password_change_required).to be(true)
    expect(user.valid_password?("1XX22CS0011XX22CS001")).to be(true)
    expect(response.body).to include("1XX22CS0011XX22CS001")
  end

  it "imports faculty with an auto-generated password shown in the results" do
    upload(<<~CSV)
      name,email,role,usn,department,sem
      Prof. Rao,rao@college.edu,faculty,,,
    CSV

    user = User.find_by(email: "rao@college.edu")
    expect(user.role).to eq("faculty")
    expect(user.password_change_required).to be(true)
    expect(user.student_profile).to be_nil
    # The generated password appears in the results table.
    password = CSV.parse(Base64.decode64(response.body[/base64,([A-Za-z0-9+\/=]+)/, 1]), headers: true)
                  .first["temporary_password"]
    expect(user.valid_password?(password)).to be(true)
  end

  it "uses the admin-supplied temporary password for staff but not students" do
    upload(<<~CSV, staff_password: "welcome2026")
      name,email,role,usn,department,sem
      Prof. Rao,rao@college.edu,faculty,,,
      Asha Kumar,asha@college.edu,student,1XX22CS001,Computer Science,3
    CSV

    faculty = User.find_by(email: "rao@college.edu")
    expect(faculty.valid_password?("welcome2026")).to be(true)
    expect(faculty.password_change_required).to be(true)

    student = User.find_by(email: "asha@college.edu")
    expect(student.valid_password?("1XX22CS0011XX22CS001")).to be(true)
  end

  it "rejects a too-short staff password without importing anything" do
    upload(<<~CSV, staff_password: "abc")
      name,email,role,usn,department,sem
      Prof. Rao,rao@college.edu,faculty,,,
    CSV

    expect(response).to redirect_to(new_admin_user_import_path)
    expect(flash[:alert]).to eq("The temporary staff password must be at least 6 characters.")
    expect(User.find_by(email: "rao@college.edu")).to be_nil
  end

  it "skips bad rows but imports the rest, reporting each error" do
    create(:user, email: "taken@college.edu")

    upload(<<~CSV)
      name,email,role,usn,department,sem
      Good One,good@college.edu,student,1XX22CS002,Computer Science,1
      Bad Role,badrole@college.edu,teacher,,,
      No Usn,nousn@college.edu,student,,Computer Science,2
      Bad Dept,baddept@college.edu,student,1XX22CS003,Astrology,2
      Dupe,taken@college.edu,faculty,,,
    CSV

    expect(User.find_by(email: "good@college.edu")).to be_present
    expect(User.find_by(email: "badrole@college.edu")).to be_nil
    expect(User.find_by(email: "baddept@college.edu")).to be_nil

    expect(response.body).to include("role must be one of")
    expect(response.body).to include("usn is required for students")
    expect(response.body).to include("Astrology")
    expect(response.body).to include("Email has already been taken")
  end

  it "serves the CSV template" do
    get template_admin_user_imports_path

    expect(response.headers["Content-Type"]).to include("text/csv")
    expect(response.body).to start_with("name,email,role,usn,department,sem")
  end

  it "rejects a missing file" do
    post admin_user_imports_path

    expect(response).to redirect_to(new_admin_user_import_path)
  end

  it "denies non-admins" do
    sign_in create(:user, :faculty)

    get new_admin_user_import_path

    expect(response).to redirect_to(root_path)
  end
end
