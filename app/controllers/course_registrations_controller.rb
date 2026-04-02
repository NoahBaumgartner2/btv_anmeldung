class CourseRegistrationsController < ApplicationController
  before_action :authenticate_user!
  # Sucht die Anmeldung anhand der ID in der URL, bevor edit, update oder destroy ausgeführt wird
  before_action :set_course_registration, only: [ :edit, :update, :destroy ]

  def new
    @course_registration = CourseRegistration.new
    @my_participants = current_user.participants

    if params[:course_id]
      @course = Course.find_by(id: params[:course_id])
      @course_registration.course_id = @course&.id
      # Nur Kurse der gleichen Kategorie anzeigen
      @selectable_courses = @course ? Course.where(registration_type: @course.registration_type).order(:title) : Course.order(:title)
    else
      @selectable_courses = Course.order(:title)
    end
  end

  def create
    @course_registration = CourseRegistration.new(course_registration_params)
    @course_registration.payment_cleared = false

    # 1. Welchen Kurs möchte das Kind buchen?
    course = @course_registration.course
    participant = @course_registration.participant

    # 2. Pflichtfelder-Check
    if course && participant
      missing = participant.missing_fields_for(course)
      if missing.any?
        labels = missing.map { |f| Participant.field_label(f) }.join(", ")
        @course_registration.errors.add(:base, "#{participant.first_name} hat folgende Pflichtangaben nicht hinterlegt: #{labels}. Bitte zuerst das Profil ergänzen.")
        setup_new_form(course)
        return render :new, status: :unprocessable_entity
      end
    end

    # 3. Wie viele BESTÄTIGTE Plätze sind schon weg?
    bestaetigte_plaetze = course.course_registrations.where(status: "bestätigt").count

    # 4. Die Wartelisten-Automatik!
    if course.max_participants.present? && bestaetigte_plaetze >= course.max_participants
      @course_registration.status = "warteliste"
      erfolgs_nachricht = "Der Kurs ist leider voll. Dein Kind wurde erfolgreich auf die Warteliste gesetzt!"
    else
      @course_registration.status = "bestätigt"
      erfolgs_nachricht = "Fantastisch! Dein Kind hat einen festen Platz im Kurs."
    end

    if @course_registration.save
      redirect_to course_path(course), notice: erfolgs_nachricht
    else
      setup_new_form(course)
      render :new, status: :unprocessable_entity
    end
  end

  # NEU: Das Formular zum Bearbeiten laden
  def edit
    course = @course_registration.course
    @selectable_courses = Course.where(registration_type: course.registration_type).order(:title)
    @my_participants = current_user.participants
    @course = course
  end

  # NEU: Die Änderungen in der Datenbank speichern
  def update
    if @course_registration.update(course_registration_params)
      redirect_to course_path(@course_registration.course), notice: "Anmeldung wurde erfolgreich aktualisiert!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # NEU: Eine Anmeldung komplett löschen/stornieren
  def destroy
    course = @course_registration.course
    @course_registration.destroy
    redirect_to course_path(course), notice: "Die Anmeldung wurde gelöscht."
  end

def scan
    authorize_trainer!

    @registration = CourseRegistration.find(params[:id])

    # 1. Wir nehmen EXAKT die Checkliste, aus der der Trainer den Scanner gestartet hat!
    if params[:session_id].present?
      @session = TrainingSession.find(params[:session_id])
    else
      # Fallback, falls jemand den Link ohne ID aufruft
      @session = @registration.course.training_sessions.order(start_time: :desc).first
    end

    # 2. Kind in dieser Liste abhaken!
    attendance = @session.attendances.find_or_create_by(course_registration_id: @registration.id)

    # (Sicherheits-Check: Falls du in der Datenbank ein echtes Feld für den Status hast, aktivieren wir es hier)
    attendance.update(present: true) if attendance.has_attribute?(:present)
    attendance.update(status: "present") if attendance.has_attribute?(:status)

    respond_to do |format|
      format.html { redirect_to @session, notice: "✅ BING! #{@registration.participant.first_name} wurde eingecheckt!" }
      format.json {
        render json: {
          success: true,
          message: "✅ #{@registration.participant.first_name} ist da!"
        }
      }
    end
  end

  private

  def set_course_registration
    @course_registration = CourseRegistration.find(params[:id])
  end

  def setup_new_form(course = nil)
    @my_participants = current_user.participants
    @course = course || @course_registration.course
    @selectable_courses = @course ? Course.where(registration_type: @course.registration_type).order(:title) : Course.order(:title)
  end

  # Der Türsteher: Erlaubt jetzt auch Status und Bezahlung!
  def course_registration_params
    params.require(:course_registration).permit(:course_id, :participant_id, :status, :payment_cleared, :holiday_deduction_claimed)
  end
end
