class CourseRegistrationsController < ApplicationController
  before_action :authenticate_user!
  # Sucht die Anmeldung anhand der ID in der URL, bevor edit, update oder destroy ausgeführt wird
  before_action :set_course_registration, only: [ :show, :edit, :update, :destroy, :cancel, :trainer_cancel, :use_abo_entry ]
  before_action :authorize_own_registration!, only: [ :show, :edit, :update, :destroy, :cancel ]

  def show
    if @course_registration.status == "ausstehend" && @course_registration.course.price_cents.to_i == 0
      course = @course_registration.course
      confirmed = course.course_registrations.where(status: "bestätigt").count
      max       = course.max_participants
      new_status = (max.present? && confirmed >= max) ? "warteliste" : "bestätigt"
      CourseRegistration.where(id: @course_registration.id, status: "ausstehend")
                        .update_all(status: new_status)
      @course_registration.reload
    end
  end

  def new
    if current_user.admin? || Trainer.exists?(user: current_user)
      redirect_to(params[:course_id] ? course_path(params[:course_id]) : root_path,
        alert: "Trainer und Admins können keine Kinder über dieses Formular anmelden. Bitte erstelle ein separates Eltern-Konto mit einer anderen E-Mail-Adresse.")
      return
    end
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
    if current_user.admin? || Trainer.exists?(user: current_user)
      redirect_to root_path, alert: "Trainer und Admins können keine Kinder über dieses Formular anmelden."
      return
    end
    @course_registration = CourseRegistration.new(course_registration_params)
    @course_registration.payment_cleared = false

    # 1. Welchen Kurs möchte das Kind buchen?
    course = @course_registration.course

    if course&.abo? && course.abo_size.present?
      @course_registration.abo_entries_total = course.abo_size
      @course_registration.abo_entries_used  = 0
    end
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

    # 2b. Alters-Check
    if course && participant && !course.accepts_participant_age?(participant)
      age = participant.age_at(course.age_reference_date)
      @course_registration.errors.add(
        :base,
        "#{participant.first_name} ist #{age} Jahre alt und erfüllt die Altersbeschränkung dieses Kurses (#{course.age_range_label}) nicht."
      )
      setup_new_form(course)
      return render :new, status: :unprocessable_entity
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
        erfolgs_nachricht = t("course_registrations.flash.waitlisted", name: participant.first_name)
      else
        @course_registration.status = "bestätigt"
        erfolgs_nachricht = t("course_registrations.flash.confirmed", name: participant.first_name)
      end
    end

    if @course_registration.save
      CourseRegistrationMailer.confirmation(@course_registration).deliver_later
      if course.has_payment? && course.price_cents.to_i > 0 && ::SumupConfig.configured? && !@course_registration.payment_cleared?
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
      redirect_to course_path(@course_registration.course), notice: t("course_registrations.flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # NEU: Eine Anmeldung komplett löschen/stornieren
  def destroy
    course               = @course_registration.course
    training_session_id  = @course_registration.training_session_id
    @course_registration.destroy
    WaitlistPromotionService.promote_next_from_waitlist(course, training_session_id: training_session_id)
    redirect_to participants_path, notice: t("course_registrations.flash.destroyed")
  end

  def cancel
    if @course_registration.status == "storniert"
      redirect_to participants_path, alert: t("course_registrations.flash.already_cancelled")
      return
    end

    @course_registration.update!(status: "storniert")
    WaitlistPromotionService.promote_next_from_waitlist(
      @course_registration.course,
      training_session_id: @course_registration.training_session_id
    )
    redirect_to participants_path, notice: "Die Anmeldung für \"#{@course_registration.course.title}\" wurde storniert."
  end

  # Trainer (oder Admin) meldet ein Kind vom Kurs ab.
  # Eltern werden per E-Mail informiert; optional wird der Admin
  # für eine allfällige Rückerstattung benachrichtigt.
  def trainer_cancel
    course = @course_registration.course

    unless current_user.admin? || trainer_assigned_to_course?(course)
      redirect_to root_path, alert: "Zugriff verweigert."
      return
    end

    if @course_registration.status == "storniert"
      redirect_to manage_course_path(course), alert: t("course_registrations.flash.already_cancelled")
      return
    end

    reason       = params[:cancellation_reason].to_s.strip
    notify_admin = ActiveModel::Type::Boolean.new.cast(params[:notify_admin])
    trainer      = Trainer.find_by(user: current_user)

    @course_registration.update!(
      status: "storniert",
      cancellation_reason: reason.presence,
      cancellation_notify_admin: notify_admin,
      cancelled_at: Time.current,
      cancelled_by_trainer: trainer
    )

    WaitlistPromotionService.promote_next_from_waitlist(
      course,
      training_session_id: @course_registration.training_session_id
    )

    # Eltern immer benachrichtigen
    CourseRegistrationMailer.cancelled_by_trainer(@course_registration).deliver_later

    # Admin nur informieren, wenn der Trainer das wünscht (z.B. Rückerstattung)
    if notify_admin
      User.where(admin: true).find_each do |admin_user|
        CourseRegistrationMailer.admin_refund_notice(@course_registration, admin_user).deliver_later
      end
    end

    notice = "#{@course_registration.participant.first_name} wurde vom Kurs abgemeldet."
    notice += " Der Administrator wurde wegen einer möglichen Rückerstattung benachrichtigt." if notify_admin
    redirect_to manage_course_path(course), notice: notice
  end

  def unsubscribe_from_session
    @course_registration = CourseRegistration.find(params[:id])
    authorize_parent_owns_registration!(@course_registration)
    return if performed?

    @training_session = @course_registration.course.training_sessions.find(params[:training_session_id])

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
    @session = if params[:session_id].present?
      TrainingSession.find_by(id: params[:session_id])
    else
      @registration.course.training_sessions.order(start_time: :desc).first
    end

    unless @session
      respond_to do |format|
        format.html { redirect_to root_path, alert: "Training-Session nicht gefunden." }
        format.json { render json: { success: false, message: "Session nicht gefunden" }, status: :not_found }
      end
      return
    end

    if @registration.course_id != @session.course_id
      respond_to do |format|
        format.html { redirect_to @session, alert: "Diese Anmeldung gehört nicht zu diesem Training." }
        format.json { render json: { success: false, message: "Anmeldung gehört nicht zu diesem Training" }, status: :unprocessable_entity }
      end
      return
    end

    # 2. Kind in dieser Liste abhaken!
    attendance = @session.attendances.find_or_initialize_by(course_registration_id: @registration.id)
    unless attendance.update(status: "anwesend")
      respond_to do |format|
        format.html { redirect_to @session, alert: "Anwesenheit konnte nicht gespeichert werden." }
        format.json { render json: { success: false, message: "Anwesenheit konnte nicht gespeichert werden" }, status: :unprocessable_entity }
      end
      return
    end

    respond_to do |format|
      format.html { redirect_to @session, notice: "✅ BING! #{@registration.participant.first_name} wurde eingecheckt!" }
      format.json {
        render json: {
          success: true,
          participant_name: "#{@registration.participant.first_name} #{@registration.participant.last_name}",
          message: "Anwesenheit erfasst"
        }
      }
    end
  end

  def use_abo_entry
    authorize_trainer!
    return if performed?

    course = @course_registration.course

    unless course.abo?
      redirect_to manage_course_path(course), alert: "Dieser Kurs ist kein Abo-Kurs."
      return
    end

    if @course_registration.abo_exhausted?
      redirect_to manage_course_path(course), alert: "#{@course_registration.participant.first_name} hat keine Eintritte mehr übrig."
      return
    end

    @course_registration.increment!(:abo_entries_used)
    remaining = @course_registration.abo_entries_remaining
    notice = "Eintritt für #{@course_registration.participant.first_name} eingelöst. Noch #{remaining} #{"Eintritt".pluralize(remaining)} übrig."
    redirect_to manage_course_path(course), notice: notice
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

  # Prüft, ob der eingeloggte Trainer dem gegebenen Kurs zugewiesen ist
  def trainer_assigned_to_course?(course)
    trainer = Trainer.find_by(user: current_user)
    return false unless trainer
    course.course_trainers.exists?(trainer_id: trainer.id)
  end

  def setup_new_form(course = nil)
    @my_participants = current_user.participants
    @course = course || @course_registration.course
    @selectable_courses = @course ? Course.where(registration_type: @course.registration_type).order(:title) : Course.order(:title)
    @training_session ||= TrainingSession.find_by(id: @course_registration.training_session_id)
  end

  # Der Türsteher: Erlaubt jetzt auch Status und Bezahlung!
  def course_registration_params
    params.require(:course_registration).permit(:course_id, :participant_id, :training_session_id, :status, :payment_cleared, :holiday_deduction_claimed, :abo_entries_total, :abo_entries_used)
  end
end
