module Admin
  class UsersController < BaseController
    def index
      authorize User
      @users = User.with_attached_photo
                   .includes(:deaned_divisions, :supervised_sub_divisions, student_profile: :department)
                   .order(:name)
      case params[:role]
      when "supervisor"
        @users = @users.faculty.joins(:supervised_sub_divisions).distinct
      when "dean"
        @users = @users.faculty.joins(:deaned_divisions).distinct
      when "admin", "faculty", "student"
        @users = @users.where(role: params[:role])
      end
      @users = @users.joins(:student_profile).where(students: { department_id: params[:department_id] }) if params[:department_id].present?
      @users = @users.joins(:student_profile).where(students: { sem: params[:sem] }) if params[:sem].present?
      if params[:q].present?
        term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].strip)}%"
        @users = @users.left_joins(:student_profile)
                       .where("users.name ILIKE :term OR users.email ILIKE :term OR students.usn ILIKE :term", term: term)
                       .distinct
      end
      @departments = Department.order(:name)
    end

    def new
      authorize User, :create?
      redirect_to new_admin_user_import_path
    end

    def create
      @user = authorize User.new(user_params)
      # Admin knows the initial password, so the user must pick their own on first login.
      @user.password_change_required = true
      if @user.save
        redirect_to admin_users_path, notice: "User created."
      else
        render "admin/user_imports/new", status: :unprocessable_entity
      end
    end

    def edit
      @user = authorize User.find(params[:id])
    end

    def update
      @user = authorize User.find(params[:id])
      # An admin password reset also forces the user to pick their own (except on self-edits).
      @user.password_change_required = true if user_params[:password].present? && @user != current_user
      if @user.update(user_update_params)
        label = @user.name.presence || @user.email
        redirect_to admin_users_path, notice: "#{label} user updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      user = authorize User.find(params[:id])
      if user == current_user
        redirect_to admin_users_path, alert: "You cannot delete your own account."
      else
        user.destroy!
        redirect_to admin_users_path, notice: "User deleted."
      end
    end

    private

    def user_params
      permitted = params.expect(user: [ :name, :email, :role, :phone, :address, :photo,
                                        :password, :password_confirmation,
                                        { student_profile_attributes: [ :id, :usn, :department_id, :sem ] } ])
      # The profile fieldset is only meaningful for students; drop stray params
      # submitted while the fieldset was hidden.
      permitted.delete(:student_profile_attributes) unless permitted[:role] == "student"
      permitted
    end

    # Leaving the password fields blank on edit keeps the current password.
    # Role is immutable after create — never accept role changes on update.
    def user_update_params
      permitted = params.expect(user: [ :name, :email, :phone, :address, :photo,
                                        :password, :password_confirmation,
                                        { student_profile_attributes: [ :id, :usn, :department_id, :sem ] } ])
      permitted.delete(:student_profile_attributes) unless @user.student?
      if permitted[:password].blank?
        permitted.except(:password, :password_confirmation)
      else
        permitted
      end
    end
  end
end
