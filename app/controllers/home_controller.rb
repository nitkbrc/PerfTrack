class HomeController < ApplicationController
  # Public landing page — no resource to authorize.
  skip_after_action :verify_authorized

  def index
  end
end
