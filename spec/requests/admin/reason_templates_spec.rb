require "rails_helper"

RSpec.describe "Admin reason templates", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:division) { create(:division, name: "Sports") }

  before { sign_in admin }

  describe "GET index" do
    it "shows shared defaults and division override sections" do
      create(:reason_template, :shared, action: "revert", message_text: "Need clearer proof")
      create(:reason_template, :reject, :shared, message_text: "Not eligible")
      create(:reason_template, :division_extra, division: division, action: "revert",
             message_text: "Sports-only clarification")

      get admin_reason_templates_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Shared defaults")
      expect(response.body).to include("Division overrides")
      expect(response.body).to include("Need clearer proof")
      expect(response.body).to include("Not eligible")
      expect(response.body).to include("Sports")
      expect(response.body).to include("Sports-only clarification")
    end
  end

  describe "POST create" do
    it "creates a shared default when division is blank" do
      expect {
        post admin_reason_templates_path, params: {
          reason_template: {
            division_id: "",
            action: "reject",
            message_text: "Duplicate of a prior claim."
          }
        }
      }.to change(ReasonTemplate.shared, :count).by(1)

      template = ReasonTemplate.order(:id).last
      expect(template).to be_shared
      expect(template.action).to eq("reject")
      expect(response).to redirect_to(admin_reason_templates_path)
    end

    it "creates a division extra" do
      expect {
        post admin_reason_templates_path, params: {
          reason_template: {
            division_id: division.id,
            action: "revert",
            message_text: "Sports-specific ask."
          }
        }
      }.to change(ReasonTemplate.division_extras, :count).by(1)

      template = ReasonTemplate.order(:id).last
      expect(template.division).to eq(division)
      expect(template).not_to be_shared
    end
  end

  describe "POST suppress / DELETE unsuppress" do
    it "hides and restores a shared default for one division" do
      template = create(:reason_template, :shared, action: "revert", message_text: "Global ask")

      expect {
        post suppress_admin_reason_template_path(template), params: { division_id: division.id }
      }.to change(ReasonTemplateSuppression, :count).by(1)

      expect(ReasonTemplate.effective_for(division: division, action: "revert")).not_to include(template)

      expect {
        delete unsuppress_admin_reason_template_path(template), params: { division_id: division.id }
      }.to change(ReasonTemplateSuppression, :count).by(-1)

      expect(ReasonTemplate.effective_for(division: division, action: "revert")).to include(template)
    end
  end

  describe "GET new" do
    it "prefills division and action from query params" do
      get new_admin_reason_template_path(division_id: division.id, action_type: "revert")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sports")
      expect(response.body).to include("value=\"revert\"")
    end
  end
end
