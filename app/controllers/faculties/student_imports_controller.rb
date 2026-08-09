module Faculties
  class StudentImportsController < BaseController
    before_action :authorize_create!

    def new
    end

    def create
      if params[:file].blank?
        redirect_to new_faculty_student_import_path, alert: "Please choose a CSV file to upload."
        return
      end

      @import = StudentCsvImport.new(params[:file])
      if @import.call
        render :create
      else
        redirect_to new_faculty_student_import_path, alert: @import.error
      end
    end

    def template
      send_data StudentCsvImport.template_csv, filename: "scats_students_template.csv", type: "text/csv"
    end

    private

    def authorize_create!
      authorize ::Student, :create?
    end
  end
end
