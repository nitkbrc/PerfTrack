require "rails_helper"

RSpec.describe DeanApprovalNotificationJob, type: :job do
  let(:dean)         { create(:user, :faculty) }
  let(:division)     { create(:division, dean: dean, div_type: "positive") }
  let(:sub_division) { create(:sub_division, division: division) }
  let(:category)     { create(:category, sub_division: sub_division, points: 20) }
  let(:request_record) do
    create(:achievement_request, category: category, title: "State-level hackathon")
      .tap { |r| r.update!(status: :supervisor_approved) }
  end

  it "notifies the student that positive points were added" do
    request_record.dean_approve!(actor: dean)

    expect { described_class.perform_now(request_record.id) }
      .to change(Notification, :count).by(1)

    notification = Notification.last
    expect(notification.recipient).to eq(request_record.student.user)
    expect(notification.achievement_request).to eq(request_record)
    expect(notification.read).to be(false)
    expect(notification.message).to include("State-level hackathon")
    expect(notification.message).to include("Positive: 20 points added to your record")
  end

  it "notifies the student that negative points were deducted" do
    division.update!(div_type: "negative")
    request_record.dean_approve!(actor: dean)

    described_class.perform_now(request_record.id)

    expect(Notification.last.message).to include("Negative: 20 points deducted from your record")
  end

  it "does nothing when the request is not dean_approved" do
    expect { described_class.perform_now(request_record.id) }
      .not_to change(Notification, :count)
  end

  it "does nothing when the request no longer exists" do
    expect { described_class.perform_now(-1) }.not_to change(Notification, :count)
  end
end
