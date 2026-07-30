require "rails_helper"

RSpec.describe "Dean dashboard", type: :request do
  let(:dean)         { create(:user, :faculty, name: "Dana Dean") }
  let(:division)     { create(:division, dean: dean) }
  let(:sub_division) { create(:sub_division, division: division) }
  let(:category)     { create(:category, sub_division: sub_division) }

  # Metric tiles render the label immediately followed by the value.
  def tile_value(body, label)
    body[%r{#{Regexp.escape(label)}</p>\s*<p[^>]*>\s*(-?\d+)\s*</p>}, 1]
  end

  before { sign_in dean }

  it "renders the overview with scoped decision metrics and campus counts" do
    create(:achievement_request, category: category).update!(status: :supervisor_approved)

    get dean_root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(dean.name)
    expect(response.body).to include("Awaiting decision")
    expect(response.body).to include("Accepted")
    expect(response.body).to include("Rejected")
    expect(response.body).to include("Your review history")
    expect(response.body).to include("Students")
    expect(response.body).to include("Departments")
    expect(response.body).to include("Faculty")
    expect(response.body).to include(dean_queue_path)
    expect(response.body).to include(dean_review_histories_path)
  end

  it "counts only requests under the dean's divisions" do
    create(:achievement_request, category: category).update!(status: :dean_approved)
    create(:achievement_request).update!(status: :dean_approved)

    get dean_root_path

    expect(tile_value(response.body, "Accepted")).to eq("1")
  end
end
