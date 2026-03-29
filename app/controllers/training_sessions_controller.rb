class TrainingSessionsController < ApplicationController
  before_action :set_training_session, only: %i[ show edit update destroy ]

  # GET /training_sessions or /training_sessions.json
  def index
    @training_sessions = TrainingSession.all
  end

  # GET /training_sessions/1 or /training_sessions/1.json
  def show
  end

  # GET /training_sessions/new
  def new
    @training_session = TrainingSession.new
  end

  # GET /training_sessions/1/edit
  def edit
  end

  # POST /training_sessions or /training_sessions.json
  def create
    @training_session = TrainingSession.new(training_session_params)

    respond_to do |format|
      if @training_session.save
        format.html { redirect_to @training_session, notice: "Training session was successfully created." }
        format.json { render :show, status: :created, location: @training_session }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @training_session.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /training_sessions/1 or /training_sessions/1.json
  def update
    respond_to do |format|
      if @training_session.update(training_session_params)
        format.html { redirect_to @training_session, notice: "Training session was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @training_session }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @training_session.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /training_sessions/1 or /training_sessions/1.json
  def destroy
    @training_session.destroy!

    respond_to do |format|
      format.html { redirect_to training_sessions_path, notice: "Training session was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_training_session
      @training_session = TrainingSession.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def training_session_params
      params.expect(training_session: [ :course_id, :start_time, :end_time, :is_canceled ])
    end
end
