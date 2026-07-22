require "rails_helper"

RSpec.describe "Supervisor sidebar navigation", type: :request do
  let(:supervisor)    { create(:user, :faculty) }
  let!(:sub_division) { create(:sub_division, supervisor: supervisor) }

  def sidebar_labels(body)
    body.scan(/scats-nav-label[^>]*>([^<]+)</).flatten.reject { |t| t == "SCATS" || t == "Profile" }
  end

  def first_link_tag(body, path)
    body[%r{<a\b[^>]*\bhref="#{Regexp.escape(path)}"[^>]*>}]
  end

  before { sign_in supervisor }

  it "keeps Students above Review queue on both supervisor and faculty pages" do
    get supervisor_root_path
    expect(response).to have_http_status(:ok)
    expect(sidebar_labels(response.body)).to eq([ "Students", "Review queue" ])
    expect(response.body).not_to include("Raise a req")

    get faculty_students_path
    expect(response).to have_http_status(:ok)
    expect(sidebar_labels(response.body)).to eq([ "Students", "Review queue" ])
    expect(response.body).not_to include("Raise a req")
  end

  it "marks only Review queue active on /supervisor" do
    get supervisor_root_path

    expect(first_link_tag(response.body, supervisor_root_path)).to include("scats-nav-link-active")
    expect(first_link_tag(response.body, faculty_students_path)).not_to include("scats-nav-link-active")
  end

  it "marks only Students active on /faculty/students" do
    get faculty_students_path

    expect(first_link_tag(response.body, faculty_students_path)).to include("scats-nav-link-active")
    expect(first_link_tag(response.body, supervisor_root_path)).not_to include("scats-nav-link-active")
  end
end
