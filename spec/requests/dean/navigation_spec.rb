require "rails_helper"

RSpec.describe "Dean sidebar navigation", type: :request do
  let(:dean)     { create(:user, :faculty) }
  let!(:division) { create(:division, dean: dean) }

  def sidebar_labels(body)
    body.scan(/scats-nav-label[^>]*>([^<]+)</).flatten
        .reject { |t| %w[SCATS Profile].include?(t) || t == "Sign out" }
  end

  def first_link_tag(body, path)
    body[%r{<a\b[^>]*\bhref="#{Regexp.escape(path)}"[^>]*>}]
  end

  before { sign_in dean }

  it "keeps Dashboard first, then Students, queue, and history" do
    get dean_root_path
    expect(response).to have_http_status(:ok)
    expect(sidebar_labels(response.body)).to eq([ "Dashboard", "Students", "Decision queue", "Review history" ])
  end

  it "marks only Dashboard active on /dean" do
    get dean_root_path

    expect(first_link_tag(response.body, dean_root_path)).to include("scats-nav-link-active")
    expect(first_link_tag(response.body, dean_queue_path)).not_to include("scats-nav-link-active")
  end

  it "marks only Decision queue active on /dean/queue" do
    get dean_queue_path

    expect(first_link_tag(response.body, dean_queue_path)).to include("scats-nav-link-active")
    expect(first_link_tag(response.body, dean_root_path)).not_to include("scats-nav-link-active")
  end
end
