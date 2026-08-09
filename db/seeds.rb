# Idempotent demo data: rerunning `bin/rails db:seed` never duplicates or
# crashes — structure uses find_or_create_by and requests are only created
# for seeded students who don't have any yet.

# Run Active Storage analyze jobs inline for this seed only so Solid Queue
# enqueue failures cannot abort seeding on a fresh deploy. Disable real SMTP
# for the same window so inline mailer jobs do not require a live mail server.
_original_active_job_adapter = ActiveJob::Base.queue_adapter
_original_mailer_perform = ActionMailer::Base.perform_deliveries
ActiveJob::Base.queue_adapter = :inline
ActionMailer::Base.perform_deliveries = false

begin

# 1x1 PNG so seeded requests pass the "at least one PNG proof" validation.
PROOF_PNG = Base64.decode64(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)

def proof
  { io: StringIO.new(PROOF_PNG), filename: "proof.png", content_type: "image/png" }
end

def seed_user(name:, email:, role:, phone:, address:)
  user = User.find_or_create_by!(email: email) do |u|
    u.name = name
    u.role = role
    u.phone = phone
    u.address = address
    u.password = role == "admin" ? "admin123" : "password123"
    u.password_change_required = false
    UserPhotoPlaceholder.attach!(u)
  end
  unless user.photo.attached?
    UserPhotoPlaceholder.attach!(user)
    user.save!
  end
  user
end

puts "Seeding profile permissions..."
Permission.ensure_defaults!

puts "Seeding system review roles..."
ReviewRole.ensure_system_roles!
Hierarchy.ensure_defaults!

puts "Seeding custom Coordinator role..."
coordinator_role = ReviewRole.find_or_create_by!(name: "Coordinator") do |role|
  role.scope = "sub_division"
  role.raiseable_on_behalf_eligible = false
  role.system_role = false
end

puts "Seeding departments..."
departments = [ "CSE", "ECE", "Mechanical" ].index_with do |name|
  Department.find_or_create_by!(name: name)
end

puts "Seeding faculty..."
dean_tech = seed_user(name: "Dr. Meera Nair", email: "meera.nair@scats.edu", role: "faculty",
                      phone: "9100000101", address: "Faculty Quarters, Block A")
dean_culture = seed_user(name: "Dr. Suresh Iyer", email: "suresh.iyer@scats.edu", role: "faculty",
                         phone: "9100000102", address: "Faculty Quarters, Block B")
dean_discipline = seed_user(name: "Dr. Arjun Rao", email: "arjun.rao@scats.edu", role: "faculty",
                            phone: "9100000103", address: "Faculty Quarters, Block C")
assoc_tech = seed_user(name: "Dr. Leela Krishnan", email: "leela.krishnan@scats.edu", role: "faculty",
                       phone: "9100000104", address: "Faculty Quarters, Block D")
sup_technical = seed_user(name: "Prof. Kavya Shetty", email: "kavya.shetty@scats.edu", role: "faculty",
                          phone: "9100000201", address: "CS Department, Room 204")
sup_culture = seed_user(name: "Prof. Anil Joshi", email: "anil.joshi@scats.edu", role: "faculty",
                        phone: "9100000202", address: "Sports Complex Office")
sup_conduct = seed_user(name: "Prof. Ravi Kumar", email: "ravi.kumar@scats.edu", role: "faculty",
                        phone: "9100000203", address: "Student Affairs Office")
coord_coding = seed_user(name: "Prof. Nisha Bhat", email: "nisha.bhat@scats.edu", role: "faculty",
                         phone: "9100000204", address: "Innovation Lab")
dean_outreach = seed_user(name: "Dr. Farah Khan", email: "farah.khan@scats.edu", role: "faculty",
                          phone: "9100000105", address: "Outreach Cell")
sup_outreach = seed_user(name: "Prof. Imran Ali", email: "imran.ali@scats.edu", role: "faculty",
                         phone: "9100000205", address: "Outreach Cell")

puts "Seeding admin..."
seed_user(name: "SCATS Admin", email: "admin@scats.edu", role: "admin",
          phone: "9000000000", address: "Administration Block, Main Campus")

puts "Seeding divisions, sub-divisions and categories..."
structure = {
  [ "Technical", "positive", dean_tech ] => {
    [ "Coding & Hackathons", sup_technical ] => {
      "National hackathon win" => 40,
      "Inter-college hackathon win" => 25,
      "Open-source contribution" => 15
    },
    [ "Paper Presentations", sup_technical ] => {
      "Journal paper published" => 50,
      "Tech fest presentation" => 10
    }
  },
  [ "Cultural & Sports", "positive", dean_culture ] => {
    [ "Sports", sup_culture ] => { "University-level medal" => 30, "Inter-college tournament" => 15 },
    [ "Cultural Events", sup_culture ] => { "Stage performance" => 10, "Event organisation" => 12 }
  },
  [ "Discipline", "negative", dean_discipline ] => {
    [ "Conduct", sup_conduct ] => {
      "Ragging incident" => 50,
      "Exam malpractice" => 40,
      "Property damage" => 20,
      "Repeated late attendance" => 10
    }
  },
  [ "Outreach", "positive", dean_outreach ] => {
    [ "Community Service", sup_outreach ] => {
      "Blood donation camp" => 10,
      "Village survey drive" => 8
    }
  }
}

categories = {}
structure.each do |(div_name, div_type, dean), sub_divisions|
  division = Division.find_or_create_by!(name: div_name) do |d|
    d.div_type = div_type
  end
  RoleAssignment.find_or_create_by!(review_role: ReviewRole.dean, division: division) do |a|
    a.user = dean
  end
  sub_divisions.each do |(sub_name, supervisor), cats|
    sub_division = SubDivision.find_or_create_by!(name: sub_name, division: division)
    RoleAssignment.find_or_create_by!(review_role: ReviewRole.supervisor, sub_division: sub_division) do |a|
      a.user = supervisor
    end
    cats.each do |cat_name, points|
      categories[cat_name] = Category.find_or_create_by!(name: cat_name, sub_division: sub_division) do |c|
        c.points = points
      end
    end
  end
end

puts "Extending Technical into a 4-step chain (Supervisor → Coordinator → Division Reviewer → Dean)..."
# Custom mid division role — not a system role; Dean stays last when present.
div_reviewer_role = ReviewRole.find_or_create_by!(name: "Division Reviewer") do |role|
  role.scope = "division"
  role.raiseable_on_behalf_eligible = false
  role.system_role = false
end
div_reviewer_role.update!(system_role: false) if div_reviewer_role.system_role?

tech = Division.find_by!(name: "Technical")

legacy_assoc = ReviewRole.find_by(name: ReviewRole::ASSOCIATE_DEAN)
if legacy_assoc
  legacy_assoc.update!(system_role: false) if legacy_assoc.system_role?
  RoleAssignment.where(review_role: legacy_assoc, division_id: tech.id).find_each do |assignment|
    if RoleAssignment.exists?(review_role: div_reviewer_role, division_id: tech.id)
      assignment.destroy!
    else
      assignment.update!(review_role: div_reviewer_role)
    end
  end
end

tech_div_hierarchy = Hierarchy.find_or_create_by!(name: "Technical Division Chain") do |h|
  h.scope = "division"
  h.is_default = false
end
unless tech_div_hierarchy.hierarchy_roles.exists?(review_role: div_reviewer_role)
  tech_div_hierarchy.insert_role!(div_reviewer_role)
end
unless tech_div_hierarchy.hierarchy_roles.exists?(review_role: ReviewRole.dean)
  tech_div_hierarchy.hierarchy_roles.create!(review_role: ReviewRole.dean, position: 99, can_raise_on_behalf: false)
  tech_div_hierarchy.normalize_positions!
end
tech.update!(hierarchy: tech_div_hierarchy)

RoleAssignment.find_or_create_by!(review_role: div_reviewer_role, division: tech) do |a|
  a.user = assoc_tech
end

coding = SubDivision.find_by!(name: "Coding & Hackathons", division: tech)
coding_hierarchy = Hierarchy.find_or_create_by!(name: "Coding Sub-division Chain") do |h|
  h.scope = "sub_division"
  h.is_default = false
end
unless coding_hierarchy.hierarchy_roles.exists?(review_role: ReviewRole.supervisor)
  coding_hierarchy.hierarchy_roles.create!(
    review_role: ReviewRole.supervisor, position: 1, can_raise_on_behalf: true
  )
end
unless coding_hierarchy.hierarchy_roles.exists?(review_role: coordinator_role)
  coding_hierarchy.insert_role!(coordinator_role)
end
coding.update!(hierarchy: coding_hierarchy)

RoleAssignment.find_or_create_by!(review_role: coordinator_role, sub_division: coding) do |a|
  a.user = coord_coding
end

puts "Seeding reason templates..."
revert_messages = [
  "Please attach clearer proof — the current image is not readable.",
  "The certificate does not mention your name; please upload the correct one.",
  "Please add the event date and organiser details to the description."
]
reject_messages = [
  "This achievement belongs under a different category.",
  "Insufficient evidence to verify this claim."
]
revert_messages.each_with_index do |text, index|
  ReasonTemplate.find_or_create_by!(division_id: nil, action: "revert", message_text: text) do |t|
    t.position = index
  end
end
reject_messages.each_with_index do |text, index|
  ReasonTemplate.find_or_create_by!(division_id: nil, action: "reject", message_text: text) do |t|
    t.position = index
  end
end
puts "Seeding students..."
student_rows = [
  [ "Asha Kumar",    "asha.kumar@scats.edu",    "1SC22CS001", "CSE", 5, "9200000001", "Hostel A, Room 101" ],
  [ "Vikram Singh",  "vikram.singh@scats.edu",  "1SC22CS002", "CSE", 5, "9200000002", "Hostel A, Room 102" ],
  [ "Priya Patel",   "priya.patel@scats.edu",   "1SC23CS003", "CSE", 3, "9200000003", "Hostel B, Room 201" ],
  [ "Rahul Desai",   "rahul.desai@scats.edu",   "1SC22EC001", "ECE", 5, "9200000004", "Hostel B, Room 202" ],
  [ "Sneha Reddy",   "sneha.reddy@scats.edu",   "1SC23EC002", "ECE", 3, "9200000005", "Hostel C, Room 301" ],
  [ "Arjun Menon",   "arjun.menon@scats.edu",   "1SC24ME001", "Mechanical", 1, "9200000006", "Hostel C, Room 302" ],
  [ "Divya Sharma",  "divya.sharma@scats.edu",  "1SC22ME002", "Mechanical", 5, "9200000007", "Hostel D, Room 401" ],
  [ "Karthik Gowda", "karthik.gowda@scats.edu", "1SC23CS004", "CSE", 3, "9200000008", "Hostel D, Room 402" ],
  # Scenario students for extended hierarchy / edge-case browsing
  [ "Neha Joshi",    "neha.joshi@scats.edu",    "1SC24CS010", "CSE", 2, "9200000010", "Hostel E, Room 501" ],
  [ "Rohan Pillai",  "rohan.pillai@scats.edu",  "1SC24CS011", "CSE", 2, "9200000011", "Hostel E, Room 502" ],
  [ "Isha Verma",    "isha.verma@scats.edu",    "1SC24CS012", "CSE", 2, "9200000012", "Hostel E, Room 503" ],
  [ "Mohan Das",     "mohan.das@scats.edu",     "1SC24CS013", "CSE", 4, "9200000013", "Hostel E, Room 504" ],
  [ "Tara Sen",      "tara.sen@scats.edu",      "1SC24EC010", "ECE", 4, "9200000014", "Hostel F, Room 601" ]
]

students_by_usn = student_rows.to_h do |name, email, usn, dept, sem, phone, address|
  user = seed_user(name: name, email: email, role: "student", phone: phone, address: address)
  student = Student.find_or_create_by!(usn: usn) do |s|
    s.user = user
    s.department = departments.fetch(dept)
    s.sem = sem
  end
  [ usn, student ]
end

puts "Seeding achievement requests..."
def request_for(student, category, title, description)
  AchievementRequest.submit!(
    student: student, actor: student.user,
    attrs: { category: category, title: title, description: description, proofs: [ proof ] }
  )
end

def supervisor_of(request) = request.category.sub_division.supervisor
def dean_of(request) = request.category.sub_division.division.dean
def reject_template_for(request)
  ReasonTemplate.effective_for(
    division: request.category.sub_division.division,
    action: "reject"
  ).first
end

def seed_requests_for(student)
  yield if student.achievement_requests.none?
end

asha = students_by_usn.fetch("1SC22CS001")
vikram = students_by_usn.fetch("1SC22CS002")
priya = students_by_usn.fetch("1SC23CS003")
rahul = students_by_usn.fetch("1SC22EC001")
sneha = students_by_usn.fetch("1SC23EC002")
arjun = students_by_usn.fetch("1SC24ME001")
divya = students_by_usn.fetch("1SC22ME002")
karthik = students_by_usn.fetch("1SC23CS004")
neha = students_by_usn.fetch("1SC24CS010")
rohan = students_by_usn.fetch("1SC24CS011")
isha = students_by_usn.fetch("1SC24CS012")
mohan = students_by_usn.fetch("1SC24CS013")
tara = students_by_usn.fetch("1SC24EC010")

# --- Classic 2-step / mixed catalog scenarios (existing demo set) ---
seed_requests_for(asha) do
  r = request_for(asha, categories["National hackathon win"], "Won Smart India Hackathon", "First place in the national finals.")
  r.advance!(actor: supervisor_of(r))
  # Technical Coding chain: Coordinator + Division Reviewer before Dean
  r.advance!(actor: coord_coding) if r.current_reviewer == coord_coding
  r.advance!(actor: assoc_tech) if r.current_reviewer == assoc_tech
  r.advance!(actor: dean_of(r)) if r.in_review?

  r = request_for(asha, categories["Open-source contribution"], "Merged PR into Rails", "Contributed a documentation fix.")
  r.advance!(actor: supervisor_of(r))
  # Parked at Coordinator on the long Coding chain

  request_for(asha, categories["Tech fest presentation"], "Presented at Techkriti", "Talk on service workers.")
end
# (assoc_tech holds custom Division Reviewer on Technical — Associate Dean is not a system role)

seed_requests_for(vikram) do
  r = request_for(vikram, categories["University-level medal"], "Gold in 400m sprint", "University athletics meet.")
  r.advance!(actor: supervisor_of(r))
  r.advance!(actor: dean_of(r))

  r = AchievementRequest.supervisor_initiate!(
    student: vikram, actor: sup_conduct,
    attrs: { category: categories["Repeated late attendance"], title: "Late to first hour 12 times",
             description: "Attendance register, March–April.", proofs: [ proof ] }
  )
  r.advance!(actor: dean_of(r))
end

seed_requests_for(priya) do
  r = request_for(priya, categories["Stage performance"], "Classical dance at Utsav", "Solo Bharatanatyam performance.")
  r.revert!(actor: supervisor_of(r), comment: "Please attach clearer proof — the current image is not readable.")
end

seed_requests_for(rahul) do
  r = request_for(rahul, categories["Inter-college tournament"], "Cricket tournament winner", "College team captain.")
  r.advance!(actor: supervisor_of(r))
  r.revert!(actor: dean_of(r), comment: "The certificate does not mention the student's name; please clarify.")
end

seed_requests_for(sneha) do
  r = request_for(sneha, categories["Journal paper published"], "Paper in IEEE Access", "Co-authored with faculty.")
  r.advance!(actor: supervisor_of(r))
  # Paper Presentations: Supervisor → Division Reviewer → Dean
end

seed_requests_for(arjun) do
  r = request_for(arjun, categories["Event organisation"], "Organised freshers' day", "Led a team of ten volunteers.")
  r.reject!(actor: supervisor_of(r), comment: "Insufficient evidence to verify this claim.", reason_template: reject_template_for(r))
end

seed_requests_for(divya) do
  r = AchievementRequest.supervisor_initiate!(
    student: divya, actor: sup_conduct,
    attrs: { category: categories["Property damage"], title: "Broken lab equipment",
             description: "Damaged an oscilloscope in the electronics lab.", proofs: [ proof ] }
  )
  r.advance!(actor: dean_of(r))

  r = request_for(divya, categories["Inter-college hackathon win"], "Won CodeStorm 2026", "Team of three, first place.")
  r.advance!(actor: supervisor_of(r))
  r.advance!(actor: coord_coding) if r.current_reviewer == coord_coding
  r.advance!(actor: assoc_tech) if r.current_reviewer == assoc_tech
  r.advance!(actor: dean_of(r)) if r.in_review?
end

seed_requests_for(karthik) do
  request_for(karthik, categories["Inter-college hackathon win"], "Runner-up at HackBlitz", "48-hour hackathon, second place.")
end

# --- Extended hierarchy / edge-case browse set ---
seed_requests_for(neha) do
  # Full 4-step approval on Coding & Hackathons
  r = request_for(neha, categories["National hackathon win"], "Won Campus Innovate 2026",
                  "Demo scenario: completed Supervisor → Coordinator → Division Reviewer → Dean.")
  r.advance!(actor: supervisor_of(r))
  r.advance!(actor: coord_coding)
  r.advance!(actor: assoc_tech)
  r.advance!(actor: dean_tech)

  # Parked at Division Reviewer for Leela's queue
  r = request_for(neha, categories["Open-source contribution"], "Maintainer on scats-cli",
                  "Demo scenario: waiting on Division Reviewer.")
  r.advance!(actor: supervisor_of(r))
  r.advance!(actor: coord_coding)
end

seed_requests_for(rohan) do
  # Mid-chain reject by Coordinator
  r = request_for(rohan, categories["Inter-college hackathon win"], "Claimed first at CodeFest",
                  "Demo scenario: rejected at Coordinator.")
  r.advance!(actor: supervisor_of(r))
  r.reject!(actor: coord_coding, comment: "Certificate does not match the claimed event.",
            reason_template: reject_template_for(r))

  # Mid-chain revert Division Reviewer → Coordinator
  r = request_for(rohan, categories["National hackathon win"], "Regional finals trophy",
                  "Demo scenario: sent back from Division Reviewer to Coordinator.")
  r.advance!(actor: supervisor_of(r))
  r.advance!(actor: coord_coding)
  r.revert!(actor: assoc_tech, comment: "Please add organiser contact details before I advance.")
end

seed_requests_for(isha) do
  # Path B into long chain (skips Supervisor → lands on Coordinator)
  r = AchievementRequest.supervisor_initiate!(
    student: isha, actor: sup_technical,
    attrs: {
      category: categories["Open-source contribution"],
      title: "Upstream patch (raised on behalf)",
      description: "Demo Path B into 4-step Technical chain.",
      proofs: [ proof ]
    }
  )
  # Leave parked at Coordinator for Nisha

  # Path B revert to originating supervisor (raiseable floor)
  r = AchievementRequest.supervisor_initiate!(
    student: isha, actor: sup_technical,
    attrs: {
      category: categories["Inter-college hackathon win"],
      title: "Team mentor note (Path B)",
      description: "Demo: Path B reverted to raising supervisor for revise.",
      proofs: [ proof ]
    }
  )
  r.revert!(actor: coord_coding, comment: "Clarify the student contribution split.")
end

seed_requests_for(mohan) do
  # Same supervisor (Kavya) across two subs — Paper Presentations uses shorter chain
  request_for(mohan, categories["Journal paper published"], "Workshop paper at NITK",
              "Demo: multi sub-division supervisor queue (Papers).")
  request_for(mohan, categories["Tech fest presentation"], "Poster at Impetus",
              "Demo: second Papers item awaiting Kavya.")
end

seed_requests_for(tara) do
  # Outreach pending then auto-rejected via archive (idempotent: only if still active)
  cat = categories["Village survey drive"]
  unless cat.archived?
    request_for(tara, cat, "Survey in coastal village",
                "Demo: will be auto-rejected when Outreach category is archived.")
    request_for(tara, categories["Blood donation camp"], "Organised campus blood drive",
                "Demo: stays active under Outreach.")
    cat.archive!(Time.current, actor: User.find_by!(email: "admin@scats.edu"))
  end
end

puts "Ensuring notifications for approved requests..."
AchievementRequest.approved.pluck(:id).each { |id| DeanApprovalNotificationJob.perform_now(id) }

puts <<~DONE

  Seeded! Demo logins (all passwords: password123, admin: admin123):

  Admin:                 admin@scats.edu
  Dean (Technical):      meera.nair@scats.edu
  Div. Reviewer (Tech):  leela.krishnan@scats.edu
  Coordinator (Coding):  nisha.bhat@scats.edu
  Supervisor (Tech×2):   kavya.shetty@scats.edu
  Dean (Discipline):     arjun.rao@scats.edu
  Student (classic):     asha.kumar@scats.edu
  Student (4-step):      neha.joshi@scats.edu
  Student (Path B):      isha.verma@scats.edu

  Technical / Coding chain: Supervisor → Coordinator → Division Reviewer → Dean
  (Associate Dean is not a system role; mid roles are ordinary custom ReviewRoles.)
DONE

ensure
  ActiveJob::Base.queue_adapter = _original_active_job_adapter
  ActionMailer::Base.perform_deliveries = _original_mailer_perform
end
