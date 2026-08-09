require "csv"

# Faculty (and shared) CSV import for student accounts only — no role column.
class StudentCsvImport
  HEADERS = %w[name email phone address usn department sem].freeze

  Result = Struct.new(:line, :name, :email, :role, :password, :error) do
    def created? = error.nil?
  end

  attr_reader :results, :error

  def self.template_csv
    department = Department.order(:name).first&.name || "Computer Science"
    CSV.generate do |csv|
      csv << HEADERS
      csv << [ "Asha Kumar", "asha@college.edu", "9876543210", "123 Campus Road", "1XX22CS001", department, "3" ]
    end
  end

  def initialize(file)
    @file = file
    @results = []
  end

  def call
    rows = CSV.parse(@file.read, headers: true, skip_blanks: true)
    rows.each.with_index(2) { |row, line| import_row(row, line) }
    true
  rescue CSV::MalformedCSVError => e
    @error = "The file could not be parsed as CSV: #{e.message}"
    false
  end

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
    result = StudentAccountCreator.call(
      name: name,
      email: email,
      phone: row["phone"],
      address: row["address"],
      usn: row["usn"],
      department: row["department"],
      sem: row["sem"]
    )

    if result.success?
      @results << Result.new(line, name, email, "student", result.password, nil)
    else
      @results << Result.new(line, name, email, "student", nil, result.error)
    end
  end
end
