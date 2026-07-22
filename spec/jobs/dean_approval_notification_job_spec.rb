require "rails_helper"

RSpec.describe DeanApprovalNotificationJob, type: :job do
  let(:dean)         { create(:user, :faculty) }
  let(:supervisor)   { create(:user, :faculty, name: "Prof. Supervisor") }
  let(:division)     { create(:division, dean: dean, div_type: "positive") }
  let(:sub_division) { create(:sub_division, division: division, supervisor: supervisor) }
  let(:category)     { create(:category, sub_division: sub_division, points: 20) }
  let(:student)      { create(:student) }

  def path_a_request(title: "State-level hackathon")
    create(:achievement_request, student: student, category: category, title: title).tap do |r|
      r.req_histories.create!(actor: student.user, action: "submit", to_status: "submitted")
      r.update!(status: :supervisor_approved)
    end
  end

  def path_b_request(title: "Conduct incident")
    create(:achievement_request, student: student, category: category, title: title,
                                 status: :supervisor_approved).tap do |r|
      r.req_histories.create!(actor: supervisor, action: "supervisor_initiate",
                              to_status: "supervisor_approved")
    end
  end

  it "notifies Path A students that positive points were added" do
    request_record = path_a_request
    request_record.dean_approve!(actor: dean)

    expect { described_class.perform_now(request_record.id) }
      .to change(Notification, :count).by(1)

    notification = Notification.last
    expect(notification.recipient).to eq(student.user)
    expect(notification.achievement_request).to eq(request_record)
    expect(notification.read).to be(false)
    expect(notification.message).to eq(
      'Your request "State-level hackathon" was approved by the dean. ' \
      "Positive: 20 points added to your record."
    )
  end

  it "notifies Path A students that negative points were verified and deducted" do
    division.update!(div_type: "negative")
    request_record = path_a_request(title: "Self-reported incident")
    request_record.dean_approve!(actor: dean)

    described_class.perform_now(request_record.id)

    expect(Notification.last.message).to eq(
      'Your request "Self-reported incident" was verified by the dean. ' \
      "Negative: 20 points deducted from your record."
    )
  end

  it "notifies Path B students that a supervisor-raised request was approved" do
    request_record = path_b_request(title: "Hackathon win")
    request_record.dean_approve!(actor: dean)

    described_class.perform_now(request_record.id)

    expect(Notification.last.message).to eq(
      'A request raised by your supervisor for "Hackathon win" was approved by the dean. ' \
      "Positive: 20 points added to your record."
    )
  end

  it "notifies Path B students that a supervisor-raised conduct record was verified" do
    division.update!(div_type: "negative")
    request_record = path_b_request(title: "Ragging incident")
    request_record.dean_approve!(actor: dean)

    described_class.perform_now(request_record.id)

    expect(Notification.last.message).to eq(
      'A conduct record raised by your supervisor for "Ragging incident" was verified by the dean. ' \
      "Negative: 20 points deducted from your record."
    )
  end

  it "does nothing when the request is not dean_approved" do
    request_record = path_a_request

    expect { described_class.perform_now(request_record.id) }
      .not_to change(Notification, :count)
  end

  it "does nothing when the request no longer exists" do
    expect { described_class.perform_now(-1) }.not_to change(Notification, :count)
  end
end
