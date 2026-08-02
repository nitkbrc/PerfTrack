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

  it "supervisor reject rejects the request (does not revert it)" do
    sign_in_as supervisor
    visit supervisor_achievement_request_path(request_record)

    open_reject_panel!
    within("form[action$='/reject']") do
      fill_in "comment", with: "Not enough evidence."
      accept_confirm { click_button "Reject" }
    end

    expect(page).to have_content("Request rejected.")
    expect(request_record.reload.status).to eq("rejected")
  end

  it "dean reject rejects the request (does not revert it)" do
    request_record.advance!(actor: supervisor)

    sign_in_as dean
    visit dean_achievement_request_path(request_record)

    open_reject_panel!
    within("form[action$='/reject']") do
      fill_in "comment", with: "Does not meet the bar."
      accept_confirm { click_button "Reject" }
    end

    expect(page).to have_content("Request rejected.")
    expect(request_record.reload.status).to eq("rejected")
  end
end
