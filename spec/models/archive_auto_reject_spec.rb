require "rails_helper"

RSpec.describe "Archive auto-reject", type: :model do
  include ActiveJob::TestHelper

  def proof_upload
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/proof.png"), "image/png"
    )
  end

  let(:admin) { create(:user, :admin) }
  let(:division) { create(:division) }
  let(:sub_division) { create(:sub_division, division: division) }
  let(:category) { create(:category, sub_division: sub_division) }

  it "rejects pending requests and leaves terminals untouched" do
    pending_student = create(:student)
    pending_req = AchievementRequest.submit!(
      student: pending_student, actor: pending_student.user,
      attrs: { category: category, title: "Pending", description: "x", proofs: [ proof_upload ] }
    )

    approved_student = create(:student)
    approved = AchievementRequest.submit!(
      student: approved_student, actor: approved_student.user,
      attrs: { category: category, title: "Approved", description: "x", proofs: [ proof_upload ] }
    )
    approved.advance!(actor: sub_division.supervisor)
    approved.advance!(actor: division.dean)

    already_rejected = create(:achievement_request, category: category, status: :rejected)

    clear_enqueued_jobs

    expect {
      category.archive!(actor: admin)
    }.to have_enqueued_mail(RequestMailer, :rejected_notification).at_least(:once)

    expect(pending_req.reload).to be_rejected
    expect(pending_req.req_histories.order(:created_at).last.action).to eq("auto_reject_archived")
    expect(approved.reload).to be_approved
    expect(already_rejected.reload).to be_rejected
    expect(category).to be_archived
  end

  it "cascades from division archive" do
    student = create(:student)
    pending_req = AchievementRequest.submit!(
      student: student, actor: student.user,
      attrs: { category: category, title: "Pending", description: "x", proofs: [ proof_upload ] }
    )
    pending_req.advance!(actor: sub_division.supervisor)

    division.archive!(actor: admin)

    expect(pending_req.reload).to be_rejected
    expect(category.reload).to be_archived
  end
end
