require "rails_helper"

RSpec.describe "Faculty sidebar navigation", type: :request do
  let(:faculty) { create(:user, :faculty) }

  def sidebar_labels(body)
    body.scan(/scats-nav-label[^>]*>([^<]+)</).flatten
        .reject { |t| %w[SCATS Profile].include?(t) || t == "Sign out" }
  end

  def first_link_tag(body, path)
    body[%r{<a\b[^>]*\bhref="#{Regexp.escape(path)}"[^>]*>}]
  end

  before { sign_in faculty }

  it "keeps Dashboard first, then Students" do
    get faculty_root_path
    expect(sidebar_labels(response.body)).to eq([ "Dashboard", "Students" ])
  end

  it "marks only Dashboard active on /faculty" do
    get faculty_root_path

    expect(first_link_tag(response.body, faculty_root_path)).to include("scats-nav-link-active")
    expect(first_link_tag(response.body, faculty_students_path)).not_to include("scats-nav-link-active")
  end

  it "marks only Students active on /faculty/students" do
    get faculty_students_path

    expect(first_link_tag(response.body, faculty_students_path)).to include("scats-nav-link-active")
    expect(first_link_tag(response.body, faculty_root_path)).not_to include("scats-nav-link-active")
  end
end
