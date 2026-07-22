require "rails_helper"

RSpec.describe "Admin user imports", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:department) { create(:department, name: "Computer Science") }

  before { sign_in admin }

  it "shows the import mode selector with manual and CSV forms" do
    get new_admin_user_import_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Import users")
    expect(response.body).to include("Import from CSV")
    expect(response.body).to include('data-controller="import-mode"')
    expect(response.body).to include('data-import-mode-mode-value="manual"')
    expect(response.body).to include('data-controller="segmented-switch"')
    expect(response.body).to include("scats-switch")
    expect(response.body).to include('id="user_role"')
    expect(response.body).to include("Admin")
    expect(response.body).to include("Faculty")
    expect(response.body).to include("Student")
    expect(response.body).to include('action="/admin/users"')
    expect(response.body).to include("CSV file")
  end


  def upload(csv_content, extra_params = {})
    file = Rack::Test::UploadedFile.new(StringIO.new(csv_content), "text/csv", original_filename: "users.csv")
    post admin_user_imports_path, params: { file: file }.merge(extra_params)
  end

  def csv_row(overrides = {})
    defaults = {
      name: "Asha Kumar", email: "asha@college.edu", role: "student",
      phone: "9876543210", address: "123 Campus Road",
      usn: "1XX22CS001", department: "Computer Science", sem: "3"
    }
    row = defaults.merge(overrides)
    [ row[:name], row[:email], row[:role], row[:phone], row[:address],
      row[:usn], row[:department], row[:sem] ].join(",")
  end

  it "imports students with a doubled-USN password that must be changed" do
    upload(<<~CSV)
      name,email,role,phone,address,usn,department,sem
      #{csv_row}
    CSV

    expect(response).to have_http_status(:ok)
    user = User.find_by(email: "asha@college.edu")
    expect(user.student_profile.usn).to eq("1XX22CS001")
    expect(user.student_profile.sem).to eq(3)
    expect(user.phone).to eq("9876543210")
    expect(user.address).to eq("123 Campus Road")
    expect(user.photo).to be_attached
    expect(user.password_change_required).to be(true)
    expect(user.valid_password?("1XX22CS0011XX22CS001")).to be(true)
    expect(response.body).to include("1XX22CS0011XX22CS001")
  end

  it "imports faculty with an auto-generated password shown in the results" do
    upload(<<~CSV)
      name,email,role,phone,address,usn,department,sem
      #{csv_row(name: "Prof. Rao", email: "rao@college.edu", role: "faculty", usn: "", department: "", sem: "")}
    CSV

    user = User.find_by(email: "rao@college.edu")
    expect(user.role).to eq("faculty")
    expect(user.photo).to be_attached
    expect(user.password_change_required).to be(true)
    expect(user.student_profile).to be_nil
    password = CSV.parse(Base64.decode64(response.body[/base64,([A-Za-z0-9+\/=]+)/, 1]), headers: true)
                  .first["temporary_password"]
    expect(user.valid_password?(password)).to be(true)
  end

  it "uses the admin-supplied temporary password for staff but not students" do
    upload(<<~CSV, staff_password: "welcome2026")
      name,email,role,phone,address,usn,department,sem
      #{csv_row(name: "Prof. Rao", email: "rao@college.edu", role: "faculty", usn: "", department: "", sem: "")}
      #{csv_row(email: "asha@college.edu")}
    CSV

    faculty = User.find_by(email: "rao@college.edu")
    expect(faculty.valid_password?("welcome2026")).to be(true)

    student = User.find_by(email: "asha@college.edu")
    expect(student.valid_password?("1XX22CS0011XX22CS001")).to be(true)
  end

  it "rejects a too-short staff password without importing anything" do
    upload(<<~CSV, staff_password: "abc")
      name,email,role,phone,address,usn,department,sem
      #{csv_row(name: "Prof. Rao", email: "rao@college.edu", role: "faculty", usn: "", department: "", sem: "")}
    CSV

    expect(response).to redirect_to(new_admin_user_import_path)
    expect(flash[:alert]).to eq("The temporary staff password must be at least 6 characters.")
    expect(User.find_by(email: "rao@college.edu")).to be_nil
  end

  it "skips bad rows but imports the rest, reporting each error" do
    create(:user, email: "taken@college.edu")

    upload(<<~CSV)
      name,email,role,phone,address,usn,department,sem
      #{csv_row(name: "Good One", email: "good@college.edu", usn: "1XX22CS002", sem: "1")}
      #{csv_row(name: "Bad Role", email: "badrole@college.edu", role: "teacher", usn: "", department: "", sem: "")}
      #{csv_row(name: "No Phone", email: "nophone@college.edu", phone: "", usn: "1XX22CS010")}
      #{csv_row(name: "No Usn", email: "nousn@college.edu", usn: "", sem: "2")}
      #{csv_row(name: "Bad Dept", email: "baddept@college.edu", usn: "1XX22CS003", department: "Astrology", sem: "2")}
      #{csv_row(name: "Dupe", email: "taken@college.edu", role: "faculty", usn: "", department: "", sem: "")}
    CSV

    expect(User.find_by(email: "good@college.edu")).to be_present
    expect(User.find_by(email: "badrole@college.edu")).to be_nil
    expect(User.find_by(email: "baddept@college.edu")).to be_nil

    expect(response.body).to include("role must be one of")
    expect(response.body).to include("phone is required")
    expect(response.body).to include("usn is required for students")
    expect(response.body).to include("Astrology")
    expect(response.body).to include("Email has already been taken")
  end

  it "serves the CSV template" do
    get template_admin_user_imports_path

    expect(response.headers["Content-Type"]).to include("text/csv")
    expect(response.body).to start_with("name,email,role,phone,address,usn,department,sem")
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
