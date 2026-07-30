require "rails_helper"

RSpec.describe "Supervisor sidebar navigation", type: :request do
  let(:supervisor)    { create(:user, :faculty) }
  let!(:sub_division) { create(:sub_division, supervisor: supervisor) }

  def sidebar_labels(body)
    body.scan(/scats-nav-label[^>]*>([^<]+)</).flatten
        .reject { |t| %w[SCATS Profile].include?(t) || t == "Sign out" }
  end

  def first_link_tag(body, path)
    body[%r{<a\b[^>]*\bhref="#{Regexp.escape(path)}"[^>]*>}]
  end

  before { sign_in supervisor }

  it "keeps Dashboard first, then Students, queue, and history" do
    get supervisor_root_path
    expect(response).to have_http_status(:ok)
    expect(sidebar_labels(response.body)).to eq([ "Dashboard", "Students", "Review queue", "Review history" ])
    expect(response.body).not_to include("Raise a req")
    expect(response.body).to include("Sign out")
    expect(response.body).to include("Are you sure you want to sign out?")

    get faculty_students_path
    expect(response).to have_http_status(:ok)
    expect(sidebar_labels(response.body)).to eq([ "Dashboard", "Students", "Review queue", "Review history" ])
    expect(response.body).not_to include("Raise a req")
  end

  it "marks only Dashboard active on /supervisor" do
    get supervisor_root_path

    expect(first_link_tag(response.body, supervisor_root_path)).to include("scats-nav-link-active")
    expect(first_link_tag(response.body, supervisor_queue_path)).not_to include("scats-nav-link-active")
    expect(first_link_tag(response.body, faculty_students_path)).not_to include("scats-nav-link-active")
  end

  it "marks only Review queue active on /supervisor/queue" do
    get supervisor_queue_path

    expect(first_link_tag(response.body, supervisor_queue_path)).to include("scats-nav-link-active")
    expect(first_link_tag(response.body, supervisor_root_path)).not_to include("scats-nav-link-active")
  end

  it "marks only Students active on /faculty/students" do
    get faculty_students_path

    expect(first_link_tag(response.body, faculty_students_path)).to include("scats-nav-link-active")
    expect(first_link_tag(response.body, supervisor_root_path)).not_to include("scats-nav-link-active")
  end
end
