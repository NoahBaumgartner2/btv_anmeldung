class ParticipantsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_participant, only: %i[show edit update destroy]

  def index
    @participants = current_user.participants
  end

  def show
  end

  def new
    @participant = Participant.new
    @participant.user_id = current_user.id unless current_user.admin?
  end

  def edit
  end

  def create
    @participant = Participant.new(participant_params)
    @participant.user_id = current_user.id unless current_user.admin?

    if @participant.save
      redirect_to participants_path, notice: "#{@participant.first_name} #{@participant.last_name} wurde erfolgreich erfasst."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @participant.update(participant_params)
      redirect_to participants_path, notice: "#{@participant.first_name} wurde erfolgreich aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @participant.destroy!
    redirect_to participants_path, notice: "Person wurde entfernt."
  end

  private

  def set_participant
    @participant = Participant.find(params.expect(:id))
  end

  def participant_params
    allowed = [:first_name, :last_name, :email, :phone_number, :ahv_number, :date_of_birth, :gender]
    allowed << :user_id if current_user.admin?
    params.expect(participant: allowed)
  end
end
