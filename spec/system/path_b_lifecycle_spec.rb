require "rails_helper"

# Path B lifecycle in a real browser (TRD section 8):
# supervisor raises the request on the student's behalf → dean approves.
RSpec.describe "Path B lifecycle", type: :system do
  include ActiveJob::TestHelper

  let!(:supervisor) { create(:user, :faculty, name: "Sup Erwiser", password: "password123") }
  let!(:dean)       { create(:user, :faculty, name: "Dean Ley", password: "password123") }
  let!(:division)   { create(:division, name: "Discipline", div_type: "negative", dean: dean) }
  let!(:sub_division) { create(:sub_division, name: "Conduct", division: division, supervisor: supervisor) }
  let!(:category)   { create(:category, name: "Ragging", points: 15, sub_division: sub_division) }
  let!(:student_user) { create(:user, name: "Asha Kumar", password: "password123") }
  let!(:student)    { create(:student, user: student_user, usn: "1XX22CS001") }

  def sign_in_as(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Log in"
    expect(page).to have_content("Signed in as #{user.email}")
  end

  def sign_out_via_nav
    click_button "Sign out", match: :first
    expect(page).to have_link("Log in")
  end

  it "goes straight to the dean and deducts points on approval" do
    # --- Supervisor raises the request (Path B) ---
    sign_in_as supervisor
    visit new_supervisor_achievement_request_path

    select "1XX22CS001 — Asha Kumar", from: "Student"
    select "Ragging (15 pts)", from: "Category"
    fill_in "Title", with: "Ragging incident report"
    fill_in "Description", with: "Reported by hostel warden."
    attach_file "Proof (PNG, max 5MB each)", Rails.root.join("spec/fixtures/files/proof.png")
    click_button "Raise request"

    expect(page).to have_content("Request raised on behalf of 1XX22CS001.")
    sign_out_via_nav

    # --- Dean approves; points are negative for a negative division ---
    sign_in_as dean
    visit dean_root_path
    expect(page).to have_content("Ragging incident report")
    click_link "Decide"
    expect(page).to have_content("Raised by supervisor on the student's behalf")

    perform_enqueued_jobs do
      accept_confirm { click_button "Approve — award points" }
      expect(page).to have_content("Request approved — -15 points awarded.")
    end
    sign_out_via_nav

    # --- Student's dashboard reflects the deduction ---
    sign_in_as student_user
    visit student_root_path
    expect(page).to have_content("-15")
    expect(page).to have_content("4.3") # sigmoid(net -15, k 50) = 4.3
    find("summary").click
    expect(page).to have_content("Negative: 15 points deducted from your record.")
  end
end
