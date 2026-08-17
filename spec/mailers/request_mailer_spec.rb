require "rails_helper"

RSpec.describe RequestMailer, type: :mailer do
  let(:student) { create(:student) }
  let(:supervisor) { create(:user, :faculty, name: "Prof Supervisor", phone: "9111111111") }
  let(:dean) { create(:user, :faculty, name: "Dean Person", phone: "9222222222") }
  let(:division) { create(:division, dean: dean) }
  let(:sub_division) { create(:sub_division, division: division, supervisor: supervisor) }
  let(:category) { create(:category, sub_division: sub_division, name: "Hackathon Win") }
  let(:request_record) do
    create(:achievement_request, student: student, category: category, title: "Campus Hackathon")
  end
  let(:actor) { student.user }

  def decoded_body(mail)
    parts = [ mail.text_part, mail.html_part ].compact
    return mail.body.decoded if parts.empty?

    parts.map { |part| part.body.decoded }.join("\n")
  end

  def expect_shared_body(mail)
    body = decoded_body(mail)
    expect(body).to include(actor.name)
    expect(body).to include(actor.email)
    expect(body).to include(student.usn)
    expect(body).to include(student.department.name)
    expect(body).to include("Hackathon Win")
    expect(body).to include("Version")
    expect(body).to include("1")
  end

  describe "#submitted_to_reviewer" do
    it "emails the supervisor with shared context" do
      mail = described_class.submitted_to_reviewer(request_record, actor: actor)

      expect(mail.to).to eq([ supervisor.email ])
      expect(mail.subject).to match(/New SCATS request|Resubmitted SCATS request/)
      expect_shared_body(mail)
      expect(decoded_body(mail)).to include(supervisor_achievement_request_url(request_record))
    end
  end

  describe "#raised_on_behalf" do
    it "emails the dean" do
      mail = described_class.raised_on_behalf(request_record, actor: supervisor, recipient: dean)

      expect(mail.to).to eq([ dean.email ])
      expect(mail.subject).to include("Supervisor-raised")
      expect(decoded_body(mail)).to include(dean_achievement_request_url(request_record))
    end
  end

  describe "#raised_on_your_behalf" do
    it "emails the student" do
      mail = described_class.raised_on_your_behalf(request_record, actor: supervisor)

      expect(mail.to).to eq([ student.user.email ])
      expect(mail.subject).to include("on your behalf")
      expect(decoded_body(mail)).to include(supervisor.name)
      expect(decoded_body(mail)).to include("Hackathon Win")
      expect(decoded_body(mail)).to include(student_achievement_request_url(request_record))
    end
  end

  describe "#forwarded_to_reviewer" do
    it "uses reforward framing when is_reforward is true" do
      mail = described_class.forwarded_to_reviewer(request_record, actor: supervisor, is_reforward: true,
                                                   recipient: dean)

      expect(mail.to).to eq([ dean.email ])
      expect(mail.subject).to include("re-forwarded")
      expect(decoded_body(mail)).to include("re-forwarded")
      expect(decoded_body(mail)).to include("The Supervisor clarified this request")
    end
  end

  describe "#reverted_to_reviewer" do
    it "names the reverting review role and includes the comment" do
      mail = described_class.reverted_to_reviewer(request_record, actor: dean, comment: "Need dates")

      expect(mail.to).to eq([ supervisor.email ])
      expect(decoded_body(mail)).to include("Need dates")
      expect(decoded_body(mail)).to include("The Dean asked for clarification on this request")
    end

    it "names a non-Dean reviewer that holds the later division step" do
      associate_dean_role = ReviewRole.find_or_create_by!(name: ReviewRole::ASSOCIATE_DEAN) do |role|
        role.scope = "division"
        role.system_role = false
      end
      hierarchy = Hierarchy.create!(name: "Dean then Associate Dean", scope: "division", is_default: false)
      hierarchy.hierarchy_roles.create!(review_role: ReviewRole.dean, position: 1, can_raise_on_behalf: false)
      hierarchy.hierarchy_roles.create!(review_role: associate_dean_role, position: 2, can_raise_on_behalf: false)
      division.update!(hierarchy: hierarchy)
      associate_dean = create(:user, :faculty, name: "Assoc Dean Person")
      RoleAssignment.create!(user: associate_dean, review_role: associate_dean_role, division: division)

      request_at_associate_dean = create(:achievement_request, student: student, category: category,
                                                               title: "Robotics championship",
                                                               at_step: associate_dean_role)
      request_at_associate_dean.revert!(actor: associate_dean, comment: "Need dates")

      mail = described_class.reverted_to_reviewer(request_at_associate_dean, actor: associate_dean,
                                                  recipient: dean, comment: "Need dates")

      expect(decoded_body(mail)).to include("The Associate Dean asked for clarification on this request")
      expect(decoded_body(mail)).not_to include("The dean asked")
    end

    it "falls back to role-free wording when the reverting role cannot be determined" do
      record = request_record
      division.role_assignments.destroy_all

      mail = described_class.reverted_to_reviewer(record, actor: dean, recipient: supervisor,
                                                  comment: "Need dates")

      expect(decoded_body(mail)).to include("A reviewer asked for clarification on this request")
      expect(decoded_body(mail)).not_to include("The  asked")
    end
  end

  describe "#reverted_to_student" do
    it "emails the student and names the returning review role" do
      mail = described_class.reverted_to_student(request_record, actor: supervisor, comment: "Add proof")

      expect(mail.to).to eq([ student.user.email ])
      expect(decoded_body(mail)).to include(student_achievement_request_url(request_record))
      expect(decoded_body(mail)).to include("Add proof")
      expect(decoded_body(mail)).to include("The Supervisor returned this request for revision")
    end

    it "falls back to role-free wording when the returning role cannot be determined" do
      record = request_record
      sub_division.role_assignments.destroy_all

      mail = described_class.reverted_to_student(record, actor: supervisor, comment: "Add proof")

      expect(decoded_body(mail)).to include("A reviewer returned this request for revision")
    end
  end

  describe "#approved_notification" do
    it "emails the given recipient" do
      mail = described_class.approved_notification(request_record, actor: dean, recipient: student.user)

      expect(mail.to).to eq([ student.user.email ])
      expect(mail.subject).to include("approved")
    end

    it "names the review role that granted final approval" do
      request_record.advance!(actor: supervisor)
      request_record.advance!(actor: dean)

      mail = described_class.approved_notification(request_record, actor: dean, recipient: student.user)

      expect(decoded_body(mail)).to include("approved by the Dean")
    end
  end

  describe "#rejected_notification" do
    it "emails the student with the reject comment" do
      mail = described_class.rejected_notification(
        request_record, actor: supervisor, recipient: student.user, comment: "Not eligible"
      )

      expect(mail.to).to eq([ student.user.email ])
      expect(decoded_body(mail)).to include("Not eligible")
    end
  end

  describe "deprecated method aliases" do
    it "keeps the old mailer action names for in-flight jobs" do
      expect(described_class.instance_methods).to include(
        :submitted_to_supervisor, :forwarded_to_dean, :reverted_to_supervisor
      )
    end
  end
end
