module Admin
  class ReasonTemplatesController < BaseController
    def index
      authorize ReasonTemplate
      @reason_templates = ReasonTemplate.order(:created_at)
    end

    def new
      @reason_template = authorize ReasonTemplate.new
    end

    def create
      @reason_template = authorize ReasonTemplate.new(reason_template_params)
      if @reason_template.save
        redirect_to admin_reason_templates_path, notice: "Reason template created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @reason_template = authorize ReasonTemplate.find(params[:id])
    end

    def update
      @reason_template = authorize ReasonTemplate.find(params[:id])
      if @reason_template.update(reason_template_params)
        redirect_to admin_reason_templates_path, notice: "Reason template updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      reason_template = authorize ReasonTemplate.find(params[:id])
      reason_template.destroy!
      redirect_to admin_reason_templates_path, notice: "Reason template deleted."
    end

    private

    def reason_template_params
      params.expect(reason_template: [ :message_text ])
    end
  end
end
