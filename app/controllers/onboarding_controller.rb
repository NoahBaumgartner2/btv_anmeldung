class OnboardingController < ApplicationController
  before_action :authenticate_user!

  def show
    redirect_to participants_path and return unless current_user.needs_onboarding?
    @user = current_user
  end

  def create
    @user = current_user
    if @user.update(family_params.merge(family_data_completed: true))
      redirect_to participants_path, notice: t("onboarding.success_notice")
    else
      render :show, status: :unprocessable_entity
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
