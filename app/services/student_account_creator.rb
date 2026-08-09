# frozen_string_literal: true

# Creates a student User + Student profile with the same rules used by admin
# manual create and faculty create/import (USN password, placeholder photo).
class StudentAccountCreator
  Result = Struct.new(:user, :password, :error, keyword_init: true) do
    def success? = error.nil?
  end

  def self.call(**attrs) = new(**attrs).call

  def initialize(name:, email:, phone:, address:, usn:, department:, sem: nil, photo: nil)
    @name = name.to_s.strip
    @email = email.to_s.strip
    @phone = phone.to_s.strip
    @address = address.to_s.strip
    @usn = usn.to_s.strip
    @department = resolve_department(department)
    @sem = sem.presence
    @photo = photo
  end

  def call
    return failure("USN is required") if @usn.blank?
    return failure("phone is required") if @phone.blank?
    return failure("address is required") if @address.blank?
    return failure(@department_error) if @department.nil?

    password = @usn * 2
    user = User.new(
      name: @name,
      email: @email,
      role: "student",
      phone: @phone,
      address: @address,
      password: password,
      password_confirmation: password,
      password_change_required: true,
      student_profile_attributes: {
        usn: @usn,
        department_id: @department.id,
        sem: @sem
      }
    )

    if @photo.present?
      user.photo.attach(@photo)
    else
      UserPhotoPlaceholder.attach!(user)
    end

    if user.save
      Result.new(user: user, password: password)
    else
      failure(user.errors.full_messages.join("; "))
    end
  end

  private

  def resolve_department(department)
    case department
    when Department
      department
    when nil
      @department_error = "department is required"
      nil
    else
      if department.is_a?(Integer) || department.to_s.match?(/\A\d+\z/)
        found = Department.find_by(id: department)
        @department_error = "department is required" if found.nil?
        return found
      end

      name = department.to_s.strip
      if name.blank?
        @department_error = "department can't be blank"
        return nil
      end

      found = Department.where("LOWER(name) = ?", name.downcase).first
      if found.nil?
        @department_error =
          "department \"#{name}\" was not found (existing: #{Department.order(:name).pluck(:name).join(', ')})"
      end
      found
    end
  end

  def failure(message)
    Result.new(error: message)
  end
end
