require "rails_helper"

RSpec.describe "Supervisor dashboard", type: :request do
  let(:supervisor)   { create(:user, :faculty, name: "Sam Supervisor") }
  let(:sub_division) { create(:sub_division, supervisor: supervisor) }
  let(:category)     { create(:category, sub_division: sub_division) }

  # Metric tiles render the label immediately followed by the value.
  def tile_value(body, label)
    body[%r{#{Regexp.escape(label)}</p>\s*<p[^>]*>\s*(-?\d+)\s*</p>}, 1]
  end

  before { sign_in supervisor }

  it "renders the overview with scoped queue metrics and campus counts" do
    create(:achievement_request, category: category, title: "Needs review")

    get supervisor_root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(supervisor.name)
    expect(response.body).to include("Pending reviews")
    expect(response.body).to include("Accepted by dean")
    expect(response.body).to include("Rejected")
    expect(response.body).to include("Your review history")
    expect(response.body).to include("Students")
    expect(response.body).to include("Departments")
    expect(response.body).to include("Faculty")
    expect(response.body).to include(supervisor_queue_path)
    expect(response.body).to include(supervisor_review_histories_path)
  end

  it "counts only requests under the supervisor's sub-divisions" do
    create(:achievement_request, category: category).update!(status: :rejected)
    create(:achievement_request).update!(status: :rejected)

    get supervisor_root_path

    expect(tile_value(response.body, "Rejected")).to eq("1")
  end
end
