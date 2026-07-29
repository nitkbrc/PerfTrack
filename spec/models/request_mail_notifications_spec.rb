require "rails_helper"

RSpec.describe "Request email notification triggers", type: :model do
  include ActiveJob::TestHelper

  let(:student) { create(:student) }
  let(:supervisor) { create(:user, :faculty, name: "Prof Supervisor") }
  let(:dean) { create(:user, :faculty, name: "Dean Person") }
  let(:division) { create(:division, dean: dean) }
  let(:sub_division) { create(:sub_division, division: division, supervisor: supervisor) }
  let(:category) { create(:category, sub_division: sub_division) }
  let(:proof) do
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/proof.png"), "image/png"
    )
  end

  def path_a_request
    AchievementRequest.submit!(
      student: student,
      actor: student.user,
      attrs: { category_id: category.id, title: "Path A", description: "Details", proofs: [ proof ] }
    )
  end

  def path_b_request
    AchievementRequest.supervisor_initiate!(
      student: student,
      actor: supervisor,
      attrs: { category_id: category.id, title: "Path B", description: "Details", proofs: [ proof ] }
    )
  end

  it "emails the supervisor on student submit" do
    expect {
      path_a_request
    }.to have_enqueued_mail(RequestMailer, :submitted_to_supervisor).once
  end

  it "emails the dean on supervisor initiate" do
    expect {
      path_b_request
    }.to have_enqueued_mail(RequestMailer, :raised_on_behalf).once
  end

  it "emails the supervisor on student resubmit" do
    request = path_a_request
    clear_enqueued_jobs
    request.transition!(to: :supervisor_reverted, actor: supervisor, action: "supervisor_revert",
                        comment: "Fix proof")
    clear_enqueued_jobs

    expect {
      request.resubmit!(actor: student.user,
                        attrs: { title: "Path A revised", description: "Fixed" })
    }.to have_enqueued_mail(RequestMailer, :submitted_to_supervisor).once
  end

  it "emails the dean on supervisor approve" do
    request = path_a_request
    clear_enqueued_jobs

    expect {
      request.transition!(to: :supervisor_approved, actor: supervisor, action: "supervisor_approve")
    }.to have_enqueued_mail(RequestMailer, :forwarded_to_dean).once
  end

  it "emails the dean on supervisor reforward" do
    request = path_b_request
    request.transition!(to: :dean_reverted, actor: dean, action: "dean_revert", comment: "Clarify")
    clear_enqueued_jobs

    expect {
      request.transition!(to: :supervisor_approved, actor: supervisor, action: "supervisor_reforward")
    }.to have_enqueued_mail(RequestMailer, :forwarded_to_dean).once
  end

  it "emails the supervisor on dean revert" do
    request = path_a_request
    request.transition!(to: :supervisor_approved, actor: supervisor, action: "supervisor_approve")
    clear_enqueued_jobs

    expect {
      request.transition!(to: :dean_reverted, actor: dean, action: "dean_revert",
                          comment: "Need dates")
    }.to have_enqueued_mail(RequestMailer, :reverted_to_supervisor).once
  end

  it "emails the student on supervisor revert" do
    request = path_a_request
    clear_enqueued_jobs

    expect {
      request.transition!(to: :supervisor_reverted, actor: supervisor, action: "supervisor_revert",
                          comment: "Need clearer proof")
    }.to have_enqueued_mail(RequestMailer, :reverted_to_student).once
  end

  it "emails the student on supervisor reject" do
    request = path_a_request
    clear_enqueued_jobs

    expect {
      request.transition!(to: :rejected, actor: supervisor, action: "supervisor_reject",
                          comment: "Not eligible")
    }.to have_enqueued_mail(RequestMailer, :rejected_notification).once
  end

  it "emails only the student on Path A dean approve" do
    request = path_a_request
    request.transition!(to: :supervisor_approved, actor: supervisor, action: "supervisor_approve")
    clear_enqueued_jobs

    expect {
      request.dean_approve!(actor: dean)
    }.to have_enqueued_mail(RequestMailer, :approved_notification).once
  end

  it "emails the student and originating supervisor on Path B dean approve" do
    request = path_b_request
    clear_enqueued_jobs

    expect {
      request.dean_approve!(actor: dean)
    }.to have_enqueued_mail(RequestMailer, :approved_notification).twice
  end

  it "emails only the student on Path A dean reject" do
    request = path_a_request
    request.transition!(to: :supervisor_approved, actor: supervisor, action: "supervisor_approve")
    clear_enqueued_jobs

    expect {
      request.transition!(to: :rejected, actor: dean, action: "dean_reject",
                          comment: "Not eligible")
    }.to have_enqueued_mail(RequestMailer, :rejected_notification).once
  end

  it "emails the student and originating supervisor on Path B dean reject" do
    request = path_b_request
    clear_enqueued_jobs

    expect {
      request.transition!(to: :rejected, actor: dean, action: "dean_reject",
                          comment: "Not eligible")
    }.to have_enqueued_mail(RequestMailer, :rejected_notification).twice
  end

  it "does not email on revise draft saves" do
    request = path_b_request
    request.transition!(to: :dean_reverted, actor: dean, action: "dean_revert", comment: "Fix")
    clear_enqueued_jobs

    expect {
      request.revise!(actor: supervisor, attrs: { title: "Clarified", description: "Dates fixed" })
    }.not_to have_enqueued_mail(RequestMailer)
  end
end
