require "rails_helper"

RSpec.describe "Faculty dashboard", type: :request do
  let(:faculty) { create(:user, :faculty, name: "Fay Faculty") }

  before { sign_in faculty }

  it "renders the campus overview with structure counts" do
    create(:department)
    create(:student)
    create(:sub_division)

    get faculty_root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(faculty.name)
    expect(response.body).to include("Campus overview")
    expect(response.body).to include("Students")
    expect(response.body).to include("Departments")
    expect(response.body).to include("Faculty")
    expect(response.body).to include("Divisions")
    expect(response.body).to include("Sub-divisions")
    expect(response.body).to include(faculty_students_path)
  end

  it "keeps the students directory at /faculty/students" do
    get faculty_students_path
    expect(response).to have_http_status(:ok)
  end
end
