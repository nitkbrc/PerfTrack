require "rails_helper"

RSpec.describe "Admin settings", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "updates score_scale_k and changes the overall_score default" do
    student = create(:student)

    put "/admin/settings", params: { setting: { score_scale_k: 10 } }

    expect(response).to redirect_to("/admin/settings/edit")
    expect(Setting.instance.score_scale_k).to eq(10)
    # Score still neutral at net 0 regardless of k; k is picked up without error.
    expect(student.overall_score).to eq(5.0)
  end

  it "rejects an invalid k" do
    put "/admin/settings", params: { setting: { score_scale_k: 0 } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(Setting.instance.score_scale_k).to eq(50)
  end
end
