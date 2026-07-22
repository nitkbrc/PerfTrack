class ProfilesController < ApplicationController
  def show
    @user = authorize current_user
  end
end
