class FamilyDataController < ApplicationController
  before_action :authenticate_user!

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(family_params)
      redirect_to account_path, notice: t("family_data.success_notice")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def family_params
    params.require(:user).permit(
      :phone_number, :street, :house_number, :zip_code,
      :city, :country, :nationality, :mother_tongue
    )
  end
end
