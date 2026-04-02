class TrainingSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_trainer!
  before_action :set_training_session, only: %i[ show edit update destroy toggle_attendance scanner cancel ]

  def index
    @training_sessions = TrainingSession.all
  end

  def show
    @registrations = @training_session.course.course_registrations
      .includes(:participant)
      .where(status: "bestätigt")
    @attendances_by_reg_id = @training_session.attendances.index_by(&:course_registration_id)
  end

  def new
    @training_session = TrainingSession.new
    if params[:course_id]
      @training_session.course_id = params[:course_id]
      @course = Course.find_by(id: params[:course_id])
    end
  end

  def create
    @training_session = TrainingSession.new(training_session_params)
    if @training_session.save
      redirect_to manage_course_path(@training_session.course), notice: "Training wurde erfolgreich hinzugefügt."
    else
      @course = Course.find_by(id: @training_session.course_id)
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

  def cancel
    @training_session.update!(is_canceled: true)

    @training_session.course.course_registrations
      .where(status: "bestätigt")
      .includes(participant: :user)
      .each do |registration|
        TrainingSessionMailer.cancellation_notice(@training_session, registration.participant.user).deliver_later
      end

    redirect_to @training_session, notice: "Das Training wurde abgesagt und alle Teilnehmenden wurden per E-Mail benachrichtigt."
  end

  # NEU: Der magische Toggle für die Anwesenheit
  def toggle_attendance
    # Wir fangen jetzt die ID der Kursanmeldung auf
    course_registration_id = params[:course_registration_id]

    # Prüfen, ob für diese Anmeldung schon eine Anwesenheit existiert
    attendance = @training_session.attendances.find_by(course_registration_id: course_registration_id)

    if attendance
      return redirect_to @training_session if attendance.abgemeldet?

      attendance.destroy
    else
      @training_session.attendances.create(course_registration_id: course_registration_id, status: "anwesend")
    end

    redirect_to @training_session
  end

  def scanner
    # Lädt einfach nur die Kamera-Ansicht für dieses Training
  end
  private

  def set_training_session
    @training_session = TrainingSession.find(params[:id])
  end

  def training_session_params
    params.require(:training_session).permit(:course_id, :start_time, :end_time, :is_canceled)
  end
end
