require "rails_helper"

RSpec.describe "Admin sidebar navigation", type: :request do
  let(:admin) { create(:user, :admin) }

  def sidebar_labels(body)
    body.scan(/scats-nav-label[^>]*>([^<]+)</).flatten
        .reject { |t| %w[SCATS Profile].include?(t) || t == "Sign out" }
  end

  def first_link_tag(body, path)
    body[%r{<a\b[^>]*\bhref="#{Regexp.escape(path)}"[^>]*>}]
  end

  before { sign_in admin }

  it "keeps Dashboard first and Divisions on the divisions path" do
    get admin_root_path
    expect(response).to have_http_status(:ok)
    expect(sidebar_labels(response.body).first).to eq("Dashboard")
    expect(response.body).to include(admin_divisions_path)
  end

  it "marks only Dashboard active on /admin" do
    get admin_root_path

    expect(first_link_tag(response.body, admin_root_path)).to include("scats-nav-link-active")
    expect(first_link_tag(response.body, admin_divisions_path)).not_to include("scats-nav-link-active")
  end

  it "marks only Divisions active on /admin/divisions" do
    get admin_divisions_path

    expect(first_link_tag(response.body, admin_divisions_path)).to include("scats-nav-link-active")
    expect(first_link_tag(response.body, admin_root_path)).not_to include("scats-nav-link-active")
  end
end
