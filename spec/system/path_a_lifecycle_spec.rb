require "rails_helper"

# Full Path A lifecycle in a real browser (TRD section 8):
# student submits → supervisor approves → dean approves →
# student sees the updated score and a notification.
RSpec.describe "Path A lifecycle", type: :system do
  include ActiveJob::TestHelper

  let!(:supervisor) { create(:user, :faculty, name: "Sup Erwiser", password: "password123") }
  let!(:dean)       { create(:user, :faculty, name: "Dean Ley", password: "password123") }
  let!(:division)   { create(:division, name: "Technical", div_type: "positive", dean: dean) }
  let!(:sub_division) { create(:sub_division, name: "Coding", division: division, supervisor: supervisor) }
  let!(:category)   { create(:category, name: "Hackathon win", points: 20, sub_division: sub_division) }
  let!(:student_user) { create(:user, name: "Asha Kumar", password: "password123") }
  let!(:student)    { create(:student, user: student_user, usn: "1XX22CS001") }

  def sign_in_as(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Log in"
    # Wait for the redirect to finish before navigating elsewhere.
    expect(page).to have_content("Signed in as #{user.email}")
  end

  def sign_out_via_nav
    click_button "Sign out", match: :first
    # Wait until the session is actually gone before signing in the next role.
    expect(page).to have_link("Log in")
  end

  it "walks a request from submission to an updated score and notification" do
    # --- Student submits (Path A) ---
    sign_in_as student_user
    visit new_student_achievement_request_path

    select "Technical", from: "Division"
    select "Coding", from: "Sub-division"
    select "Hackathon win (20 pts)", from: "Category"
    fill_in "Title", with: "Won the state hackathon"
    fill_in "Description", with: "First place among 40 teams."
    attach_file "Proof (PNG, max 5MB each)", Rails.root.join("spec/fixtures/files/proof.png")
    click_button "Submit request"

    expect(page).to have_content("Your request has been submitted.")
    expect(page).to have_content("Won the state hackathon")
    expect(page).to have_content("Submitted")
    sign_out_via_nav

    # --- Supervisor approves and forwards ---
    sign_in_as supervisor
    visit supervisor_root_path
    expect(page).to have_content("Won the state hackathon")
    click_link "Review"
    click_button "Approve & forward to dean"

    expect(page).to have_content("Request approved and forwarded to the dean.")
    sign_out_via_nav

    # --- Dean approves; the notification job runs inline ---
    sign_in_as dean
    visit dean_root_path
    expect(page).to have_content("Won the state hackathon")
    click_link "Decide"
    perform_enqueued_jobs do
      accept_confirm { click_button "Approve — award points" }
      expect(page).to have_content("Request approved — 20 points awarded.")
    end
    sign_out_via_nav

    # --- Student sees the new score and the notification ---
    sign_in_as student_user
    visit student_root_path

    expect(page).to have_content("Dean approved")
    expect(page).to have_content("6.0") # sigmoid(net 20, k 50) = 6.0
    within("nav") { expect(page).to have_content("1") } # unread badge
    find("summary").click
    expect(page).to have_content('Your request "Won the state hackathon" was approved by the dean.')
    expect(page).to have_content("Positive: 20 points added to your record.")
  end
end
