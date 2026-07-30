class ErrorsController < ActionController::Base
  layout "error"

  def show
    render_error(status_from_request)
  end

  def not_found
    render_error(404)
  end

  def unprocessable
    render_error(422)
  end

  def internal_server_error
    render_error(500)
  end

  private

  def status_from_request
    code = request.path_info.delete_prefix("/").to_i
    code.between?(400, 599) ? code : 500
  end

  def render_error(status)
    @status = status
    render template_for(status), status: status
  end

  def template_for(status)
    case status
    when 404 then "errors/not_found"
    when 422 then "errors/unprocessable"
    when 400 then "errors/bad_request"
    else "errors/internal_server_error"
    end
  end
end
