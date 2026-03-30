class TrainingSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_trainer!
  before_action :authorize_admin! # Nur Trainer/Admins dürfen das!
  before_action :set_training_session, only: %i[ show edit update destroy toggle_attendance ]

  def index
    @training_sessions = TrainingSession.all
  end

  def show
    # Wir laden für die Checkliste nur die Teilnehmer, deren Status "bestätigt" ist
    @registrations = @training_session.course.course_registrations.includes(:participant).where(status: "bestätigt")
  end

  def new
    @training_session = TrainingSession.new
    if params[:course_id]
      @training_session.course_id = params[:course_id]
    end
  end

  def create
    @training_session = TrainingSession.new(training_session_params)
    if @training_session.save
      redirect_to @training_session, notice: "Training erfolgreich erstellt. Du kannst jetzt die Anwesenheit eintragen."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @training_session.update(training_session_params)
      redirect_to @training_session, notice: "Training aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    course = @training_session.course
    @training_session.destroy
    redirect_to course_path(course), notice: "Training gelöscht."
  end

# NEU: Der magische Toggle für die Anwesenheit
def toggle_attendance
    # Wir fangen jetzt die ID der Kursanmeldung auf
    course_registration_id = params[:course_registration_id]

    # Prüfen, ob für diese Anmeldung schon eine Anwesenheit existiert
    attendance = @training_session.attendances.find_by(course_registration_id: course_registration_id)

    if attendance
      attendance.destroy # War anwesend -> jetzt auf abwesend setzen
    else
      @training_session.attendances.create(course_registration_id: course_registration_id) # Auf anwesend setzen
    end

    redirect_to @training_session
  end

  private

  def set_training_session
    @training_session = TrainingSession.find(params[:id])
  end

# Hinweis: Ich gehe davon aus, dass deine Spalte in der DB "date" heisst.
def training_session_params
    # HIER :start_time statt :date
    params.require(:training_session).permit(:course_id, :start_time)
  end
end
