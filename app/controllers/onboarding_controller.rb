class OnboardingController < ApplicationController
  before_action :authenticate_user!

  def show
    redirect_to participants_path and return unless current_user.needs_onboarding?
    @participant = Participant.new(user_id: current_user.id)
  end

  def create
    @participant = Participant.new(participant_params)
    @participant.user_id = current_user.id

    if @participant.save
      redirect_to participants_path,
        notice: "Super! #{@participant.first_name} wurde erfasst. Du kannst jetzt Kurse buchen."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def participant_params
    params.expect(participant: [
      :first_name, :last_name, :date_of_birth, :gender, :phone_number,
      :street, :house_number, :zip_code, :city, :country, :nationality, :mother_tongue
    ])
  end
end
