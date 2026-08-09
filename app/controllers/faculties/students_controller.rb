module Faculties
  class StudentsController < BaseController
    def index
      authorize ::Student
      @students = ::Student.includes(:department, user: { photo_attachment: :blob })
                          .joins(:user).order("users.name")
      @students = @students.where(department_id: params[:department_id]) if params[:department_id].present?
      @students = @students.where(sem: params[:sem]) if params[:sem].present?
      if params[:q].present?
        term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].strip)}%"
        @students = @students.where(
          "users.name ILIKE :term OR users.email ILIKE :term OR students.usn ILIKE :term",
          term: term
        )
      end
      @departments = Department.order(:name)
      @scores = ::Student.overall_scores
      @can_create_students = current_user.can_create_students?
    end

    def show
      @student = authorize ::Student.includes(:department, user: { photo_attachment: :blob })
                                    .find(params[:id])

      approved = @student.achievement_requests.approved
                         .includes(category: { sub_division: :division })
                         .order(updated_at: :desc)
      @positive_requests, @negative_requests = approved.partition { |r| r.points_awarded.positive? }
      @positive_total = @positive_requests.sum(&:points_awarded)
      @negative_total = @negative_requests.sum(&:points_awarded)
    end

    def new
      authorize ::Student, :create?
      @user = User.new(role: "student")
      @user.build_student_profile
      @departments = Department.order(:name)
    end

    def create
      authorize ::Student, :create?

      result = StudentAccountCreator.call(**student_create_attrs)
      if result.success?
        redirect_to faculty_student_path(result.user.student_profile),
                    notice: "Student created. Temporary password is their USN typed twice — they must change it on first login."
      else
        @user = User.new(role: "student", name: params.dig(:user, :name), email: params.dig(:user, :email),
                         phone: params.dig(:user, :phone), address: params.dig(:user, :address))
        @user.build_student_profile(
          usn: params.dig(:user, :student_profile_attributes, :usn),
          department_id: params.dig(:user, :student_profile_attributes, :department_id),
          sem: params.dig(:user, :student_profile_attributes, :sem)
        )
        result.error.to_s.split("; ").each { |msg| @user.errors.add(:base, msg) }
        @departments = Department.order(:name)
        render :new, status: :unprocessable_entity
      end
    end

    private

    def student_create_attrs
      profile = params.fetch(:user, {}).permit(
        :name, :email, :phone, :address, :photo,
        student_profile_attributes: [ :usn, :department_id, :sem ]
      )
      photo = profile[:photo]
      photo = nil if photo.blank?

      {
        name: profile[:name],
        email: profile[:email],
        phone: profile[:phone],
        address: profile[:address],
        usn: profile.dig(:student_profile_attributes, :usn),
        department: profile.dig(:student_profile_attributes, :department_id),
        sem: profile.dig(:student_profile_attributes, :sem),
        photo: photo
      }
    end
  end
end
