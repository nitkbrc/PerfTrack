class ProfilesController < ApplicationController
  def show
    @user = authorize User.includes(:deaned_divisions, supervised_sub_divisions: :division)
                           .find(current_user.id)
  end
end
