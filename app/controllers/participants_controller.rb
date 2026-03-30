class ParticipantsController < ApplicationController
  before_action :set_participant, only: %i[ show edit update destroy ]
  before_action :authenticate_user! # Muss eingeloggt sein
  before_action :authorize_admin!   # MUSS Admin sein!
# GET /participants or /participants.json
def index
    if params[:query].present?
      # ILIKE ist der Postgres-Befehl für eine Groß-/Kleinschreibung-unabhängige Suche
      @participants = Participant.where("first_name ILIKE ? OR last_name ILIKE ?", "%#{params[:query]}%", "%#{params[:query]}%")
    else
      @participants = Participant.all
    end
  end

  # GET /participants/1 or /participants/1.json
  def show
  end

  # GET /participants/new
  def new
    @participant = Participant.new
  end

  # GET /participants/1/edit
  def edit
  end

  # POST /participants or /participants.json
  def create
    @participant = Participant.new(participant_params)

    respond_to do |format|
      if @participant.save
        format.html { redirect_to @participant, notice: "Participant was successfully created." }
        format.json { render :show, status: :created, location: @participant }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @participant.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /participants/1 or /participants/1.json
  def update
    respond_to do |format|
      if @participant.update(participant_params)
        format.html { redirect_to @participant, notice: "Participant was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @participant }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @participant.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /participants/1 or /participants/1.json
  def destroy
    @participant.destroy!

    respond_to do |format|
      format.html { redirect_to participants_path, notice: "Participant was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_participant
      @participant = Participant.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def participant_params
      params.expect(participant: [ :user_id, :first_name, :last_name, :email, :phone_number, :ahv_number, :date_of_birth, :gender ])
    end
end
