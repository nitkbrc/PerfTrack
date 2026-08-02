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
sup_technical = seed_user(name: "Prof. Kavya Shetty", email: "kavya.shetty@scats.edu", role: "faculty",
                          phone: "9100000201", address: "CS Department, Room 204")
sup_culture = seed_user(name: "Prof. Anil Joshi", email: "anil.joshi@scats.edu", role: "faculty",
                        phone: "9100000202", address: "Sports Complex Office")
sup_conduct = seed_user(name: "Prof. Ravi Kumar", email: "ravi.kumar@scats.edu", role: "faculty",
                        phone: "9100000203", address: "Student Affairs Office")

puts "Seeding admin..."
seed_user(name: "SCATS Admin", email: "admin@scats.edu", role: "admin",
          phone: "9000000000", address: "Administration Block, Main Campus")

puts "Seeding divisions, sub-divisions and categories..."
structure = {
  [ "Technical", "positive", dean_tech ] => {
    [ "Coding & Hackathons", sup_technical ] => { "National hackathon win" => 40, "Inter-college hackathon win" => 25, "Open-source contribution" => 15 },
    [ "Paper Presentations", sup_technical ] => { "Journal paper published" => 50, "Tech fest presentation" => 10 }
  },
  [ "Cultural & Sports", "positive", dean_culture ] => {
    [ "Sports", sup_culture ] => { "University-level medal" => 30, "Inter-college tournament" => 15 },
    [ "Cultural Events", sup_culture ] => { "Stage performance" => 10, "Event organisation" => 12 }
  },
  [ "Discipline", "negative", dean_discipline ] => {
    [ "Conduct", sup_conduct ] => { "Ragging incident" => 50, "Exam malpractice" => 40, "Property damage" => 20, "Repeated late attendance" => 10 }
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

puts "Seeding reason templates..."
[
  "Please attach clearer proof — the current image is not readable.",
  "The certificate does not mention your name; please upload the correct one.",
  "This achievement belongs under a different category. Please resubmit accordingly.",
  "Insufficient evidence to verify this claim.",
  "Please add the event date and organiser details to the description."
].each { |text| ReasonTemplate.find_or_create_by!(message_text: text) }

puts "Seeding students..."
student_rows = [
  [ "Asha Kumar",    "asha.kumar@scats.edu",    "1SC22CS001", "CSE", 5, "9200000001", "Hostel A, Room 101" ],
  [ "Vikram Singh",  "vikram.singh@scats.edu",  "1SC22CS002", "CSE", 5, "9200000002", "Hostel A, Room 102" ],
  [ "Priya Patel",   "priya.patel@scats.edu",   "1SC23CS003", "CSE", 3, "9200000003", "Hostel B, Room 201" ],
  [ "Rahul Desai",   "rahul.desai@scats.edu",   "1SC22EC001", "ECE", 5, "9200000004", "Hostel B, Room 202" ],
  [ "Sneha Reddy",   "sneha.reddy@scats.edu",   "1SC23EC002", "ECE", 3, "9200000005", "Hostel C, Room 301" ],
  [ "Arjun Menon",   "arjun.menon@scats.edu",   "1SC24ME001", "Mechanical", 1, "9200000006", "Hostel C, Room 302" ],
  [ "Divya Sharma",  "divya.sharma@scats.edu",  "1SC22ME002", "Mechanical", 5, "9200000007", "Hostel D, Room 401" ],
  [ "Karthik Gowda", "karthik.gowda@scats.edu", "1SC23CS004", "CSE", 3, "9200000008", "Hostel D, Room 402" ]
]

students = student_rows.map do |name, email, usn, dept, sem, phone, address|
  user = seed_user(name: name, email: email, role: "student", phone: phone, address: address)
  Student.find_or_create_by!(usn: usn) do |s|
    s.user = user
    s.department = departments.fetch(dept)
    s.sem = sem
  end
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
def any_template = ReasonTemplate.order("RANDOM()").first

asha, vikram, priya, rahul, sneha, arjun, divya, karthik = students

# Each block is skipped when the student already has requests, keeping the
# seed rerunnable.
if asha.achievement_requests.none?
  r = request_for(asha, categories["National hackathon win"], "Won Smart India Hackathon", "First place in the national finals.")
  r.advance!(actor: supervisor_of(r))
  r.advance!(actor: dean_of(r))

  r = request_for(asha, categories["Open-source contribution"], "Merged PR into Rails", "Contributed a documentation fix.")
  r.advance!(actor: supervisor_of(r))

  request_for(asha, categories["Tech fest presentation"], "Presented at Techkriti", "Talk on service workers.")
end

if vikram.achievement_requests.none?
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

if priya.achievement_requests.none?
  r = request_for(priya, categories["Stage performance"], "Classical dance at Utsav", "Solo Bharatanatyam performance.")
  r.revert!(actor: supervisor_of(r), comment: "Please attach clearer proof — the current image is not readable.")
end

if rahul.achievement_requests.none?
  r = request_for(rahul, categories["Inter-college tournament"], "Cricket tournament winner", "College team captain.")
  r.advance!(actor: supervisor_of(r))
  r.revert!(actor: dean_of(r), comment: "The certificate does not mention the student's name; please clarify.")
end

if sneha.achievement_requests.none?
  r = request_for(sneha, categories["Journal paper published"], "Paper in IEEE Access", "Co-authored with faculty.")
  r.advance!(actor: supervisor_of(r))
end

if arjun.achievement_requests.none?
  r = request_for(arjun, categories["Event organisation"], "Organised freshers' day", "Led a team of ten volunteers.")
  r.reject!(actor: supervisor_of(r), comment: "Insufficient evidence to verify this claim.", reason_template: any_template)
end

if divya.achievement_requests.none?
  r = AchievementRequest.supervisor_initiate!(
    student: divya, actor: sup_conduct,
    attrs: { category: categories["Property damage"], title: "Broken lab equipment",
             description: "Damaged an oscilloscope in the electronics lab.", proofs: [ proof ] }
  )
  r.advance!(actor: dean_of(r))

  r = request_for(divya, categories["Inter-college hackathon win"], "Won CodeStorm 2026", "Team of three, first place.")
  r.advance!(actor: supervisor_of(r))
  r.advance!(actor: dean_of(r))
end

if karthik.achievement_requests.none?
  request_for(karthik, categories["Inter-college hackathon win"], "Runner-up at HackBlitz", "48-hour hackathon, second place.")
end

# advance! final approval already enqueues DeanApprovalNotificationJob asynchronously;
# run it inline too so notifications exist even if the queue worker isn't
# around. The job is idempotent, so overlapping runs are harmless.
puts "Ensuring notifications for approved requests..."
AchievementRequest.approved.pluck(:id).each { |id| DeanApprovalNotificationJob.perform_now(id) }

puts <<~DONE

  Seeded! Demo logins (all passwords: password123, admin: admin123):
    Admin:              admin@scats.edu
    Dean (Technical):   meera.nair@scats.edu
    Dean (Discipline):  arjun.rao@scats.edu
    Supervisor:         kavya.shetty@scats.edu
    Student:            asha.kumar@scats.edu
DONE

ensure
  ActiveJob::Base.queue_adapter = _original_active_job_adapter
  ActionMailer::Base.perform_deliveries = _original_mailer_perform
end
