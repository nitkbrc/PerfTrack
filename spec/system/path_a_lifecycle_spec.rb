require "rails_helper"

# Full Path A lifecycle in a real browser (TRD section 8):
# student submits → supervisor advances → dean approves →
# student sees the updated score and a notification.
RSpec.describe "Path A lifecycle", type: :system do
  include ActiveJob::TestHelper
  include Warden::Test::Helpers

  let!(:supervisor) { create(:user, :faculty, name: "Sup Erwiser", password: "password123") }
  let!(:dean)       { create(:user, :faculty, name: "Dean Ley", password: "password123") }
  let!(:division)   { create(:division, name: "Technical", div_type: "positive", dean: dean) }
  let!(:sub_division) { create(:sub_division, name: "Coding", division: division, supervisor: supervisor) }
  let!(:category)   { create(:category, name: "Hackathon win", points: 20, sub_division: sub_division) }
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

  it "walks a request from submission to an updated score and notification" do
    proof = fixture_file_upload("proof.png", "image/png")
    AchievementRequest.submit!(
      student: student,
      actor: student_user,
      attrs: {
        category_id: category.id,
        title: "Won the state hackathon",
        description: "First place among 40 teams.",
        proofs: [ proof ]
      }
    )

    sign_in_as supervisor
    visit supervisor_queue_path
    expect(page).to have_content("Won the state hackathon")
    click_link "Review"
    click_button "Advance to next reviewer"
    expect(page).to have_content("Request advanced to the next reviewer.")
    sign_out_user

    sign_in_as dean
    visit dean_queue_path
    expect(page).to have_content("Won the state hackathon")
    click_link "Decide"
    expect(page).to have_button("Approve — award points")

    perform_enqueued_jobs do
      accept_confirm { click_button "Approve — award points" }
      expect(page).to have_content("Request approved — 20 points awarded.")
    end
    sign_out_user

    sign_in_as student_user
    visit student_root_path

    expect(page).to have_content("Approved by Dean Ley")
    expect(page).to have_content("6.0") # sigmoid(net 20, k 50) = 6.0
    within("#notifications") { expect(page).to have_content("1") }
    find("summary").click
    expect(page).to have_content('Your request "Won the state hackathon" was approved by the Dean.')
    expect(page).to have_content("Positive: 20 points added to your record.")
  end
end
