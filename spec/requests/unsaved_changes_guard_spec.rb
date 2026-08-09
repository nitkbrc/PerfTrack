require "rails_helper"

RSpec.describe "Unsaved changes leave guard", type: :request do
  it "embeds the leave-guard modal on admin pages" do
    admin = create(:user, :admin)
    sign_in admin

    get admin_hierarchies_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="leave-guard"')
    expect(response.body).to include("Discard & leave")
    expect(response.body).to include("Save & exit")
    expect(response.body).to include("Stay on page")
    expect(response.body).to include('data-controller="hierarchy-templates unsaved-changes"')
  end

  it "embeds the leave-guard modal on authenticated app pages" do
    faculty = create(:user, :faculty)
    sign_in faculty

    get profile_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="leave-guard"')
    expect(response.body).to include('data-controller="unsaved-changes"')
  end
end
