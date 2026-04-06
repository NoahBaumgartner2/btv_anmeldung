class CourseRegistrationsController < ApplicationController
  before_action :authenticate_user!
  # Sucht die Anmeldung anhand der ID in der URL, bevor edit, update oder destroy ausgeführt wird
  before_action :set_course_registration, only: [ :show, :edit, :update, :destroy, :cancel ]
  before_action :authorize_own_registration!, only: [ :show, :edit, :update, :destroy, :cancel ]

  def show
    if @course_registration.status == "ausstehend" && @course_registration.course.price_cents.to_i == 0
      course = @course_registration.course
      confirmed = course.course_registrations.where(status: "bestätigt").count
      max       = course.max_participants
      new_status = (max.present? && confirmed >= max) ? "warteliste" : "bestätigt"
      @course_registration.update_columns(status: new_status)
    end
  end

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

    if params[:training_session_id]
      @training_session = TrainingSession.find_by(id: params[:training_session_id])
      @course_registration.training_session_id = @training_session&.id
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

    # 3. Status bestimmen
    if course.has_payment? && course.price_cents.to_i > 0
      # Kostenpflichtiger Kurs → erst nach Bezahlung bestätigt
      @course_registration.status = "ausstehend"
    else
      # Kostenlos → sofort bestätigt oder Warteliste, Kapazität je nach Modus prüfen
      bestaetigte_plaetze = if course.registration_mode == "single_session" && @course_registration.training_session_id.present?
        course.course_registrations
              .where(status: "bestätigt", training_session_id: @course_registration.training_session_id)
              .count
      else
        course.course_registrations.where(status: "bestätigt").count
      end

      if course.max_participants.present? && bestaetigte_plaetze >= course.max_participants
        @course_registration.status = "warteliste"
        erfolgs_nachricht = "Der Kurs ist leider voll. Dein Kind wurde erfolgreich auf die Warteliste gesetzt!"
      else
        @course_registration.status = "bestätigt"
        erfolgs_nachricht = "Fantastisch! Dein Kind hat einen festen Platz im Kurs."
      end
    end

    if @course_registration.save
      CourseRegistrationMailer.confirmation(@course_registration).deliver_later
      if course.has_payment? && course.price_cents.to_i > 0 && ::StripeConfig.configured? && !@course_registration.payment_cleared?
        redirect_to checkout_preview_registration_path(@course_registration)
      else
        redirect_to course_registration_path(@course_registration), notice: erfolgs_nachricht
      end
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
    @course_registration.destroy
    redirect_to participants_path, notice: "Die Anmeldung wurde gelöscht."
  end

  def cancel
    if @course_registration.status == "storniert"
      redirect_to participants_path, alert: "Diese Anmeldung ist bereits storniert."
      return
    end

    @course_registration.update!(status: "storniert")
    redirect_to participants_path, notice: "Die Anmeldung für \"#{@course_registration.course.title}\" wurde storniert."
  end

def unsubscribe_from_session
    @course_registration = CourseRegistration.find(params[:id])
    authorize_parent_owns_registration!(@course_registration)
    return if performed?

    @training_session = TrainingSession.find(params[:training_session_id])

    unless @training_session.start_time > 24.hours.from_now
      redirect_to participants_path, alert: "Eine Abmeldung ist nur bis 24 Stunden vor dem Training möglich."
      return
    end

    attendance = @training_session.attendances.find_or_initialize_by(
      course_registration_id: @course_registration.id
    )
    attendance.update!(status: "abgemeldet")

    User.where(admin: true).each do |admin_user|
      TrainingSessionMailer.session_unsubscription_notice(
        @training_session, @course_registration, admin_user
      ).deliver_later
    end

    participant_name = @course_registration.participant.first_name
    session_date = I18n.l(@training_session.start_time.to_date)
    redirect_to participants_path,
                notice: "#{participant_name} wurde vom Training am #{session_date} abgemeldet."
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
    attendance = @session.attendances.find_or_initialize_by(course_registration_id: @registration.id)
    attendance.update!(status: "anwesend")

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

  def mark_as_paid
    authorize_admin!
    return if performed?

    @course_registration = CourseRegistration.find(params[:id])
    course = @course_registration.course

    new_status = if course.max_participants.present?
      confirmed = course.course_registrations.where(status: "bestätigt").where.not(id: @course_registration.id).count
      confirmed >= course.max_participants ? "warteliste" : "bestätigt"
    else
      "bestätigt"
    end

    @course_registration.update!(payment_cleared: true, status: new_status)
    redirect_to manage_course_path(course), notice: "#{@course_registration.participant.first_name} als bezahlt markiert."
  end

  private

  def set_course_registration
    @course_registration = CourseRegistration.find(params[:id])
  end

  def authorize_own_registration!
    unless current_user.admin? || current_user.participants.include?(@course_registration.participant)
      redirect_to root_path, alert: "Zugriff verweigert."
    end
  end

  def setup_new_form(course = nil)
    @my_participants = current_user.participants
    @course = course || @course_registration.course
    @selectable_courses = @course ? Course.where(registration_type: @course.registration_type).order(:title) : Course.order(:title)
    @training_session ||= TrainingSession.find_by(id: @course_registration.training_session_id)
  end

  # Der Türsteher: Erlaubt jetzt auch Status und Bezahlung!
  def course_registration_params
    params.require(:course_registration).permit(:course_id, :participant_id, :training_session_id, :status, :payment_cleared, :holiday_deduction_claimed)
  end
end
