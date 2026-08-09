module Admin
  class ReasonTemplatesController < BaseController
    def index
      authorize ReasonTemplate
      @shared_templates = ReasonTemplate.shared.ordered.includes(:division)
      @divisions = Division.active
                           .includes(:reason_templates, :reason_template_suppressions)
                           .order(:name)
    end

    def new
      @reason_template = authorize ReasonTemplate.new(
        division_id: params[:division_id].presence,
        action: params[:action_type].presence_in(ReasonTemplate::ACTIONS)
      )
      load_form_collections
    end

    def create
      @reason_template = authorize ReasonTemplate.new(reason_template_params)
      if @reason_template.save
        notice = @reason_template.shared? ? "Shared default created." : "Division override created."
        redirect_to admin_reason_templates_path, notice: notice
      else
        load_form_collections
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @reason_template = authorize ReasonTemplate.find(params[:id])
      load_form_collections
    end

    def update
      @reason_template = authorize ReasonTemplate.find(params[:id])
      if @reason_template.update(reason_template_params)
        redirect_to admin_reason_templates_path, notice: "Reason template updated."
      else
        load_form_collections
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      reason_template = authorize ReasonTemplate.find(params[:id])
      reason_template.destroy!
      redirect_to admin_reason_templates_path, notice: "Reason template deleted."
    end

    def suppress
      template = authorize ReasonTemplate.find(params[:id]), :update?
      unless template.shared?
        redirect_to admin_reason_templates_path, alert: "Only shared defaults can be hidden per division."
        return
      end

      division = Division.find(params[:division_id])
      ReasonTemplateSuppression.find_or_create_by!(division: division, reason_template: template)
      redirect_to admin_reason_templates_path, notice: "Hidden “#{truncate_notice(template)}” for #{division.name}."
    end

    def unsuppress
      template = authorize ReasonTemplate.find(params[:id]), :update?
      division = Division.find(params[:division_id])
      ReasonTemplateSuppression.find_by!(division: division, reason_template: template).destroy!
      redirect_to admin_reason_templates_path, notice: "Restored “#{truncate_notice(template)}” for #{division.name}."
    end

    private

    def reason_template_params
      permitted = params.expect(reason_template: [ :message_text, :division_id, :action ])
      permitted[:division_id] = permitted[:division_id].presence
      permitted
    end

    def load_form_collections
      @divisions = Division.active.order(:name)
    end

    def truncate_notice(template)
      template.message_text.to_s.truncate(40)
    end
  end
end
