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

  describe "#submitted_to_supervisor" do
    it "emails the supervisor with shared context" do
      mail = described_class.submitted_to_supervisor(request_record, actor: actor)

      expect(mail.to).to eq([ supervisor.email ])
      expect(mail.subject).to match(/New SCATS request|Resubmitted SCATS request/)
      expect_shared_body(mail)
      expect(decoded_body(mail)).to include(supervisor_achievement_request_url(request_record))
    end
  end

  describe "#raised_on_behalf" do
    it "emails the dean" do
      mail = described_class.raised_on_behalf(request_record, actor: supervisor)

      expect(mail.to).to eq([ dean.email ])
      expect(mail.subject).to include("Supervisor-raised")
      expect(decoded_body(mail)).to include(dean_achievement_request_url(request_record))
    end
  end

  describe "#forwarded_to_dean" do
    it "uses reforward framing when is_reforward is true" do
      mail = described_class.forwarded_to_dean(request_record, actor: supervisor, is_reforward: true)

      expect(mail.to).to eq([ dean.email ])
      expect(mail.subject).to include("re-forwarded")
      expect(decoded_body(mail)).to include("re-forwarded")
    end
  end

  describe "#reverted_to_supervisor" do
    it "includes the dean comment" do
      mail = described_class.reverted_to_supervisor(request_record, actor: dean, comment: "Need dates")

      expect(mail.to).to eq([ supervisor.email ])
      expect(decoded_body(mail)).to include("Need dates")
    end
  end

  describe "#reverted_to_student" do
    it "emails the student" do
      mail = described_class.reverted_to_student(request_record, actor: supervisor, comment: "Add proof")

      expect(mail.to).to eq([ student.user.email ])
      expect(decoded_body(mail)).to include(student_achievement_request_url(request_record))
      expect(decoded_body(mail)).to include("Add proof")
    end
  end

  describe "#approved_notification" do
    it "emails the given recipient" do
      mail = described_class.approved_notification(request_record, actor: dean, recipient: student.user)

      expect(mail.to).to eq([ student.user.email ])
      expect(mail.subject).to include("approved")
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
end
