require "csv"

# Bulk user creation from an admin-uploaded CSV. Each row is imported
# independently so one bad row never blocks the rest; the per-row results
# (including generated temporary passwords) feed the results page and its
# downloadable CSV.
class UserCsvImport
  HEADERS = %w[name email role usn department sem].freeze
  ROLES = %w[admin faculty student].freeze

  Result = Struct.new(:line, :name, :email, :role, :password, :error) do
    def created? = error.nil?
  end

  attr_reader :results

  def self.template_csv
    # Use a real department so the example row would actually import.
    department = Department.order(:name).first&.name || "Computer Science"
    CSV.generate do |csv|
      csv << HEADERS
      csv << [ "Asha Kumar", "asha@college.edu", "student", "1XX22CS001", department, "3" ]
      csv << [ "Prof. Rao", "rao@college.edu", "faculty", "", "", "" ]
    end
  end

  def initialize(file, staff_password: nil)
    @file = file
    @staff_password = staff_password
    @results = []
  end

  def call
    if @staff_password && @staff_password.length < 6
      @error = "The temporary staff password must be at least 6 characters."
      return false
    end

    rows = CSV.parse(@file.read, headers: true, skip_blanks: true)
    rows.each.with_index(2) { |row, line| import_row(row, line) }
    true
  rescue CSV::MalformedCSVError => e
    @error = "The file could not be parsed as CSV: #{e.message}"
    false
  end

  attr_reader :error

  def created = results.select(&:created?)
  def failed = results.reject(&:created?)

  def results_csv
    CSV.generate do |csv|
      csv << %w[line name email role status temporary_password error]
      results.each do |r|
        csv << [ r.line, r.name, r.email, r.role,
                 r.created? ? "created" : "failed", r.password, r.error ]
      end
    end
  end

  private

  def import_row(row, line)
    name = row["name"].to_s.strip
    email = row["email"].to_s.strip
    role = row["role"].to_s.strip.downcase
    usn = row["usn"].to_s.strip

    unless ROLES.include?(role)
      return add_result(line, name, email, role, nil, "role must be one of: #{ROLES.join(', ')}")
    end

    if role == "student" && usn.blank?
      return add_result(line, name, email, role, nil, "usn is required for students")
    end

    # Students get a predictable temporary password (their USN twice, which
    # also clears Devise's 6-char minimum); staff get the admin-chosen one, or
    # a random one that is only ever visible in these results.
    password = role == "student" ? usn * 2 : (@staff_password || SecureRandom.alphanumeric(12))

    user = User.new(name: name, email: email, role: role,
                    password: password, password_confirmation: password,
                    password_change_required: true)
    user.student_profile = build_student(row, usn, user) if role == "student"

    if user.save
      add_result(line, name, email, role, password, nil)
    else
      add_result(line, name, email, role, nil, user.errors.full_messages.join("; "))
    end
  rescue DepartmentNotFound => e
    add_result(line, name, email, role, nil, e.message)
  end

  class DepartmentNotFound < StandardError; end

  def build_student(row, usn, user)
    dept_name = row["department"].to_s.strip
    department = Department.where("LOWER(name) = ?", dept_name.downcase).first
    if department.nil?
      raise DepartmentNotFound,
            "department \"#{dept_name}\" was not found (existing: #{Department.order(:name).pluck(:name).join(', ')})"
    end

    Student.new(usn: usn, department: department, sem: row["sem"].presence, user: user)
  end

  def add_result(line, name, email, role, password, error)
    @results << Result.new(line, name, email, role, password, error)
  end
end
