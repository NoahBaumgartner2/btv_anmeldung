class TrainingSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_trainer!
  before_action :set_training_session, only: %i[ show edit update destroy toggle_attendance scanner cancel uncancel ]

  # Gezielte CSP-Erweiterung nur für die Scanner-Seite, damit html5-qrcode
  # funktioniert – ohne 'unsafe-inline'/'unsafe-eval' für script-src:
  #
  # - script-src:     self + unpkg (CDN) + per-Request-Nonce (global aktiv) für unser Inline-Script
  # - style-src:      bleibt strikt :self – wir injizieren keine <style>-Tags
  # - style-src-attr: 'unsafe-inline' erlaubt *nur* dynamische style="..."-Attribute,
  #                   die html5-qrcode beim Aufbau seiner UI setzt. Betrifft NICHT script-src.
  # - worker-src:     self + blob: – html5-qrcode startet QR-Decoder ggf. als Blob-Worker
  # - media-src:      self + blob: – Kamera-Stream wird teils via Blob-URL angebunden
  # - img-src:        zusätzlich blob: für Canvas-Snapshots
  content_security_policy(only: :scanner) do |policy|
    policy.script_src     :self, "https://unpkg.com"
    policy.style_src      :self
    policy.style_src_attr :unsafe_inline
    policy.img_src        :self, :data, :https, :blob
    policy.media_src      :self, :blob
    policy.worker_src     :self, :blob
    policy.connect_src    :self
  end

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
        next unless registration.participant&.user.present?
        TrainingSessionMailer.cancellation_notice(@training_session, registration.participant.user).deliver_later
      end

    redirect_to @training_session, notice: "Das Training wurde abgesagt und alle Teilnehmenden wurden per E-Mail benachrichtigt."
  end

  def uncancel
    authorize_admin!
    return if performed?

    @training_session.update!(is_canceled: false)
    redirect_to @training_session, notice: "Die Absage wurde rückgängig gemacht. Das Training ist wieder aktiv."
  end

  # NEU: Der magische Toggle für die Anwesenheit
  def toggle_attendance
    return redirect_to @training_session, alert: "Training ist abgesagt – Anwesenheit kann nicht erfasst werden." if @training_session.is_canceled?

    # Wir fangen jetzt die ID der Kursanmeldung auf
    course_registration_id = params[:course_registration_id]

    course_registration = CourseRegistration.find_by(id: course_registration_id)
    unless course_registration && course_registration.course_id == @training_session.course_id
      return redirect_to @training_session, alert: "Ungültige Kursanmeldung."
    end

    # Prüfen, ob für diese Anmeldung schon eine Anwesenheit existiert
    attendance = @training_session.attendances.find_by(course_registration_id: course_registration_id)

    if attendance
      return redirect_to @training_session if attendance.abgemeldet?

      attendance.destroy
    else
      attendance = @training_session.attendances.create(course_registration_id: course_registration_id, status: "anwesend")
      unless attendance.persisted?
        return redirect_to @training_session, alert: "Anwesenheit konnte nicht gespeichert werden."
      end
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
