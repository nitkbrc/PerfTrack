require "rails_helper"

# Path B lifecycle in a real browser (TRD section 8):
# supervisor raises the request on the student's behalf → dean approves.
RSpec.describe "Path B lifecycle", type: :system do
  include ActiveJob::TestHelper
  include Warden::Test::Helpers

  let!(:supervisor) { create(:user, :faculty, name: "Sup Erwiser", password: "password123") }
  let!(:dean)       { create(:user, :faculty, name: "Dean Ley", password: "password123") }
  let!(:division)   { create(:division, name: "Discipline", div_type: "negative", dean: dean) }
  let!(:sub_division) { create(:sub_division, name: "Conduct", division: division, supervisor: supervisor) }
  let!(:category)   { create(:category, name: "Ragging", points: 15, sub_division: sub_division) }
  let!(:student_user) { create(:user, name: "Asha Kumar", password: "password123") }
  let!(:student)    { create(:student, user: student_user, usn: "1XX22CS001") }

  before { Warden.test_mode! }
  after { Warden.test_reset! }

  def sign_in_as(user)
    login_as(user, scope: :user)
  end

  def sign_out_user
    logout(:user)
  end

  it "goes straight to the dean and deducts points on approval" do
    sign_in_as supervisor
    visit new_supervisor_achievement_request_path

    select "1XX22CS001 — Asha Kumar", from: "Student"
    select "Ragging (15 pts)", from: "Category"
    fill_in "Title", with: "Ragging incident report"
    fill_in "Description", with: "Reported by hostel warden."
    attach_file "Proof (PNG, max 5MB each)", Rails.root.join("spec/fixtures/files/proof.png")
    click_button "Raise request"

    expect(page).to have_content("Request raised on behalf of 1XX22CS001.")
    sign_out_user

    sign_in_as dean
    visit dean_queue_path
    expect(page).to have_content("Ragging incident report")
    click_link "Decide"
    expect(page).to have_content("Raised by supervisor on the student's behalf")

    perform_enqueued_jobs do
      accept_confirm { click_button "Approve — award points" }
      expect(page).to have_content("Request approved — -15 points awarded.")
    end
    sign_out_user

    sign_in_as student_user
    visit student_root_path
    expect(page).to have_content("-15")
    expect(page).to have_content("4.3") # sigmoid(net -15, k 50) = 4.3
    find("summary").click
    expect(page).to have_content(
      'A conduct record raised by your supervisor for "Ragging incident report" was verified by the dean.'
    )
    expect(page).to have_content("Negative: 15 points deducted from your record.")
  end
end
