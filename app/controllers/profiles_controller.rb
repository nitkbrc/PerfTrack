class ProfilesController < ApplicationController
  PROFILE_FIELDS = {
    phone: "edit_own_phone",
    address: "edit_own_address",
    photo: "edit_own_photo"
  }.freeze

  def show
    @user = authorize User.includes(role_assignments: [ :division, { sub_division: :division } ])
                           .find(current_user.id)
    @editable = editable_fields_for(@user)
  end

  def update
    @user = authorize User.find(current_user.id)
    @editable = editable_fields_for(@user)

    if @user.update(profile_params)
      redirect_to profile_path, notice: "Profile updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def editable_fields_for(user)
    return PROFILE_FIELDS.keys.index_with { true } if user.admin?

    PROFILE_FIELDS.transform_values { |action| Permission.enabled_for?(user.role, action) }
  end

  def profile_params
    permitted = []
    permitted << :phone if @editable[:phone]
    permitted << :address if @editable[:address]
    permitted << :photo if @editable[:photo]
    params.fetch(:user, {}).permit(*permitted)
  end
end
