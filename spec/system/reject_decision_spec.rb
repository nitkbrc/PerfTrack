require "rails_helper"

# Regression for the Turbo submitter bug: Reject used to share a form with
# Revert via formaction:, and accepting the turbo_confirm dialog resubmitted
# the form without the button — silently performing a revert instead. These
# specs click Reject in a real browser and assert the request is rejected.
RSpec.describe "Reject decisions", type: :system do
  include Warden::Test::Helpers

  let!(:supervisor) { create(:user, :faculty, name: "Sup Erwiser", password: "password123") }
  let!(:dean)       { create(:user, :faculty, name: "Dean Ley", password: "password123") }
  let!(:division)   { create(:division, div_type: "positive", dean: dean) }
  let!(:sub_division) { create(:sub_division, division: division, supervisor: supervisor) }
  let!(:category)   { create(:category, sub_division: sub_division) }
  let!(:reject_reason) do
    create(:reason_template, :shared, :reject, message_text: "Not enough evidence to verify this claim.")
  end
  let!(:request_record) do
    create(:achievement_request, category: category, at_step: :supervisor, title: "Borderline claim")
  end

  before { Warden.test_mode! }
  after { Warden.test_reset! }

  def sign_in_as(user)
    login_as(user, scope: :user)
  end

  def open_reject_panel!
    within('[aria-label="Decision action"]') { click_button "Reject" }
  end

  def submit_reject!(message)
    within("form[action$='/reject']") do
      select message.truncate(80), from: "reason_template_id"
      accept_confirm { click_button "Reject" }
    end
  end

  it "supervisor reject rejects the request (does not revert it)" do
    sign_in_as supervisor
    visit supervisor_achievement_request_path(request_record)

    open_reject_panel!
    submit_reject!(reject_reason.message_text)

    expect(page).to have_content("Request rejected.")
    expect(request_record.reload.status).to eq("rejected")
  end

  it "dean reject rejects the request (does not revert it)" do
    request_record.advance!(actor: supervisor)

    sign_in_as dean
    visit dean_achievement_request_path(request_record)

    open_reject_panel!
    submit_reject!(reject_reason.message_text)

    expect(page).to have_content("Request rejected.")
    expect(request_record.reload.status).to eq("rejected")
  end
end
