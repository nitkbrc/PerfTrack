require "rails_helper"

RSpec.describe "Admin divisions", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "creates a division with a free faculty dean" do
    dean = create(:user, :faculty)

    expect {
      post "/admin/divisions", params: { division: { name: "Sports", div_type: "positive", dean_user_id: dean.id } }
    }.to change(Division, :count).by(1)

    expect(response).to redirect_to("/admin/divisions")
  end

  it "re-renders the form with the exclusivity error when the dean is already a supervisor" do
    supervisor = create(:user, :faculty)
    create(:sub_division, supervisor: supervisor)

    expect {
      post "/admin/divisions", params: { division: { name: "Sports", div_type: "positive", dean_user_id: supervisor.id } }
    }.not_to change(Division, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("is already a supervisor of a sub-division")
  end
end
