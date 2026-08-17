require "rails_helper"

RSpec.describe FinalApprovalNotificationJob, type: :job do
  let(:dean)         { create(:user, :faculty) }
  let(:supervisor)   { create(:user, :faculty, name: "Prof. Supervisor") }
  let(:division)     { create(:division, dean: dean, div_type: "positive") }
  let(:sub_division) { create(:sub_division, division: division, supervisor: supervisor) }
  let(:category)     { create(:category, sub_division: sub_division, points: 20) }
  let(:student)      { create(:student) }

  def path_a_request(title: "State-level hackathon")
    create(:achievement_request, student: student, category: category, title: title, at_step: :dean).tap do |r|
      r.req_histories.create!(actor: student.user, action: "submit", to_status: "in_review",
                              request_version: r.current_version)
    end
  end

  def path_b_request(title: "Conduct incident")
    create(:achievement_request, student: student, category: category, title: title, at_step: :dean).tap do |r|
      r.req_histories.create!(actor: supervisor, action: "supervisor_initiate",
                              to_status: "in_review",
                              request_version: r.current_version)
    end
  end

  it "notifies Path A students that positive points were added" do
    request_record = path_a_request
    request_record.advance!(actor: dean)

    expect { described_class.perform_now(request_record.id) }
      .to change(Notification, :count).by(1)

    notification = Notification.last
    expect(notification.recipient).to eq(student.user)
    expect(notification.achievement_request).to eq(request_record)
    expect(notification.read).to be(false)
    expect(notification.message).to eq(
      'Your request "State-level hackathon" was approved by the Dean. ' \
      "Positive: 20 points added to your record."
    )
  end

  it "notifies Path A students that negative points were verified and deducted" do
    division.update!(div_type: "negative")
    request_record = path_a_request(title: "Self-reported incident")
    request_record.advance!(actor: dean)

    described_class.perform_now(request_record.id)

    expect(Notification.last.message).to eq(
      'Your request "Self-reported incident" was verified by the Dean. ' \
      "Negative: 20 points deducted from your record."
    )
  end

  it "notifies Path B students that a supervisor-raised request was approved" do
    request_record = path_b_request(title: "Hackathon win")
    request_record.advance!(actor: dean)

    described_class.perform_now(request_record.id)

    expect(Notification.last.message).to eq(
      'A request raised by your supervisor for "Hackathon win" was approved by the Dean. ' \
      "Positive: 20 points added to your record."
    )
  end

  it "notifies Path B students that a supervisor-raised conduct record was verified" do
    division.update!(div_type: "negative")
    request_record = path_b_request(title: "Ragging incident")
    request_record.advance!(actor: dean)

    described_class.perform_now(request_record.id)

    expect(Notification.last.message).to eq(
      'A conduct record raised by your supervisor for "Ragging incident" was verified by the Dean. ' \
      "Negative: 20 points deducted from your record."
    )
  end

  it "names the actual final approver when the chain does not end on Dean" do
    associate_dean_role = ReviewRole.find_or_create_by!(name: ReviewRole::ASSOCIATE_DEAN) do |role|
      role.scope = "division"
      role.system_role = false
    end
    hierarchy = Hierarchy.create!(name: "Dean then Associate Dean", scope: "division", is_default: false)
    hierarchy.hierarchy_roles.create!(review_role: ReviewRole.dean, position: 1, can_raise_on_behalf: false)
    hierarchy.hierarchy_roles.create!(review_role: associate_dean_role, position: 2, can_raise_on_behalf: false)
    division.update!(hierarchy: hierarchy)
    associate_dean = create(:user, :faculty)
    RoleAssignment.create!(user: associate_dean, review_role: associate_dean_role, division: division)

    request_record = create(:achievement_request, student: student, category: category,
                                                  title: "Robotics championship", at_step: associate_dean_role)
    request_record.req_histories.create!(actor: student.user, action: "submit", to_status: "in_review",
                                        request_version: request_record.current_version)
    request_record.advance!(actor: associate_dean)

    described_class.perform_now(request_record.id)

    expect(Notification.last.message).to eq(
      'Your request "Robotics championship" was approved by the Associate Dean. ' \
      "Positive: 20 points added to your record."
    )
  end

  it "drops the role clause when the approving role cannot be determined" do
    request_record = path_a_request(title: "Orphaned approval")
    request_record.advance!(actor: dean)
    division.role_assignments.destroy_all

    described_class.perform_now(request_record.id)

    expect(Notification.last.message).to eq(
      'Your request "Orphaned approval" was approved. ' \
      "Positive: 20 points added to your record."
    )
  end

  it "does nothing when the request is not approved" do
    request_record = path_a_request

    expect { described_class.perform_now(request_record.id) }
      .not_to change(Notification, :count)
  end

  it "does nothing when the request no longer exists" do
    expect { described_class.perform_now(-1) }.not_to change(Notification, :count)
  end

  it "keeps DeanApprovalNotificationJob as a deserialize alias" do
    expect(DeanApprovalNotificationJob).to be < FinalApprovalNotificationJob
  end
end
