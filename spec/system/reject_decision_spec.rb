require "rails_helper"

# Regression for the Turbo submitter bug: Reject used to share a form with
# Revert via formaction:, and accepting the turbo_confirm dialog resubmitted
# the form without the button — silently performing a revert instead. These
# specs click Reject in a real browser and assert the request is rejected.
RSpec.describe "Reject decisions", type: :system do
  let!(:supervisor) { create(:user, :faculty, name: "Sup Erwiser", password: "password123") }
  let!(:dean)       { create(:user, :faculty, name: "Dean Ley", password: "password123") }
  let!(:division)   { create(:division, div_type: "positive", dean: dean) }
  let!(:sub_division) { create(:sub_division, division: division, supervisor: supervisor) }
  let!(:category)   { create(:category, sub_division: sub_division) }
  let!(:request_record) do
    create(:achievement_request, category: category, status: :submitted, title: "Borderline claim")
  end

  def sign_in_as(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Log in"
    expect(page).to have_content("Signed in as #{user.email}")
  end

  it "supervisor reject rejects the request (does not revert it)" do
    sign_in_as supervisor
    visit supervisor_achievement_request_path(request_record)

    within("form[action$='/reject']") do
      fill_in "comment", with: "Not enough evidence."
    end
    accept_confirm do
      within("form[action$='/reject']") { click_button "Reject" }
    end

    expect(page).to have_content("Request rejected.")
    expect(request_record.reload.status).to eq("rejected")
  end

  it "dean reject rejects the request (does not revert it)" do
    request_record.update!(status: :supervisor_approved)

    sign_in_as dean
    visit dean_achievement_request_path(request_record)

    within("form[action$='/reject']") do
      fill_in "comment", with: "Does not meet the bar."
    end
    accept_confirm do
      within("form[action$='/reject']") { click_button "Reject" }
    end

    expect(page).to have_content("Request rejected.")
    expect(request_record.reload.status).to eq("rejected")
  end
end
