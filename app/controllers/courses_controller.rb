class CoursesController < ApplicationController
  # Für neue Kurse oder Bearbeitung MUSS man Admin sein
  before_action :authorize_admin!, except: [ :index, :show, :manage, :participant_search, :manual_enroll, :send_custom_email, :toggle_talent ]
  # GET /courses or /courses.json
  before_action :authorize_trainer!, only: [ :manage, :send_custom_email, :toggle_talent ]
  before_action :set_course, only: %i[ show edit update destroy confirm_destroy generate_trainings create_generated_trainings manage grant_access revoke_access participant_search manual_enroll send_custom_email toggle_talent roll_over ]
  def index
    all_restricted = Course.where(restricted: true).includes(:course_registrations, :permitted_users, :training_sessions)
    @restricted_courses = if current_user&.admin?
      all_restricted
    elsif current_user
      all_restricted.select { |c| c.accessible_by?(current_user) && c.registration_window_open_for?(current_user) }
    else
      []
    end
    @restricted_courses = @restricted_courses.sort_by { |c| c.weekly_sort_key + [ c.title.to_s ] }

    public_scope = Course.where(restricted: false).includes(:course_registrations, :training_sessions)
    @public_courses = if current_user&.admin?
      public_scope.to_a
    else
      public_scope.select { |c| c.registration_window_open_for?(current_user) }
    end
    @public_courses = @public_courses.sort_by { |c| c.weekly_sort_key + [ c.title.to_s ] }
  end

  # GET /courses/1 or /courses/1.json
  def show
  end

  # GET /courses/new
  def new
    @course = Course.new
  end

  # GET /courses/1/edit
  def edit
  end

  # POST /courses or /courses.json
  def create
    @course = Course.new(course_params)
    @course.registration_type = derive_registration_type(@course.registration_mode)

    respond_to do |format|
      if @course.save
        provision_new_trainer(@course)
        save_trainer_permissions(@course)
        result = generate_training_sessions_from_form(@course)

        notice = "Kurs wurde erfolgreich erstellt."
        notice += " #{result[:created]} #{"Training".pluralize(result[:created])} automatisch erstellt." if result && result[:created] > 0

        format.html { redirect_to manage_course_path(@course), notice: notice }
        format.json { render :show, status: :created, location: @course }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @course.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /courses/1 or /courses/1.json
  def update
    respond_to do |format|
      p = course_params
      p[:registration_type] = derive_registration_type(p[:registration_mode])

      old_start_hour   = @course.default_start_hour
      old_start_minute = @course.default_start_minute
      old_end_hour     = @course.default_end_hour
      old_end_minute   = @course.default_end_minute
      old_max          = @course.max_participants

      if @course.update(p)
        provision_new_trainer(@course)
        save_trainer_permissions(@course)
        result = generate_training_sessions_from_form(@course)

        # Wurde die Teilnehmerzahl erhöht, können freigewordene Plätze sofort
        # mit Wartelisten-Einträgen aufgefüllt werden (vorher nur bei Storno/Ablauf).
        promote_waitlist_after_capacity_increase(old_max)

        time_changed = old_start_hour   != @course.default_start_hour   ||
                       old_start_minute != @course.default_start_minute ||
                       old_end_hour     != @course.default_end_hour     ||
                       old_end_minute   != @course.default_end_minute

        if time_changed && @course.default_start_hour.present?
          @course.training_sessions
                 .where("start_time >= ?", Time.current.beginning_of_day)
                 .where(is_canceled: false)
                 .find_each do |session|
            base = session.start_time.in_time_zone
            new_start = base.change(
              hour: @course.default_start_hour.to_i,
              min:  @course.default_start_minute.to_i
            )
            new_end = if @course.default_end_hour.present?
              base.change(
                hour: @course.default_end_hour.to_i,
                min:  @course.default_end_minute.to_i
              )
            end
            session.update_columns(start_time: new_start, end_time: new_end)
          end
        end

        notice = "Kurs wurde erfolgreich aktualisiert."
        notice += " #{result[:created]} #{"Training".pluralize(result[:created])} automatisch ergänzt." if result && result[:created] > 0

        format.html { redirect_to manage_course_path(@course), notice: notice, status: :see_other }
        format.json { render :show, status: :ok, location: @course }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @course.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /courses/1 or /courses/1.json
  def destroy
    @course.destroy!

    respond_to do |format|
      format.html { redirect_to courses_path, notice: "Kurs wurde erfolgreich gelöscht.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # POST /courses/1/confirm_destroy
  def confirm_destroy
    unless current_user.valid_password?(params[:admin_password])
      return redirect_to @course,
        alert: "Falsches Passwort. Der Kurs wurde nicht gelöscht.",
        status: :see_other
    end

    course_title = @course.title
    @course.destroy!

    redirect_to courses_path,
      notice: "Kurs \"#{course_title}\" wurde erfolgreich gelöscht.",
      status: :see_other
  end

  # Zeigt das Formular für den Generator an
  def generate_trainings
  end

  # Führt die Magie aus!
  def create_generated_trainings
    unless @course.start_date.present? && @course.end_date.present?
      redirect_to generate_trainings_course_path(@course),
                  alert: "Dieser Kurs hat kein Start- oder Enddatum. Bitte zuerst den Kurs bearbeiten.",
                  status: :see_other and return
    end

    unless params[:start_hour].present? && params[:day_of_week].present?
      redirect_to generate_trainings_course_path(@course),
                  alert: "Bitte Wochentag und Startzeit auswählen.",
                  status: :see_other and return
    end

    start_uhrzeit = "#{params[:start_hour]}:#{format('%02d', params[:start_minute].to_i)}"
    end_uhrzeit   = params[:end_hour].present? ? "#{params[:end_hour]}:#{format('%02d', params[:end_minute].to_i)}" : nil

    result = generate_training_sessions(
      @course,
      weekdays: [ params[:day_of_week].to_i ],
      start_uhrzeit: start_uhrzeit,
      end_uhrzeit: end_uhrzeit,
      holiday_ids: Array(params[:holiday_ids]).map(&:to_i),
      extra_holidays: parse_extra_holidays(params[:extra_holidays])
    )

    notice = "#{result[:created]} #{"Training".pluralize(result[:created])} erstellt"
    notice += ", #{result[:skipped]} übersprungen (Ferien oder bereits vorhanden)" if result[:skipped] > 0

    redirect_to manage_course_path(@course), notice: notice, status: :see_other
  end

  def manage
    @manual_participant = Participant.new(country: "CH", nationality: "CH", mother_tongue: "DE")
    @show_manual_create_panel = false
    set_manage_view_ivars
  end

  # POST /courses/:id/roll_over – manuelles Auslösen der Verlängerung
  # (bei Kursen mit auto_rollover: false, siehe RolloverCoursePeriodsJob).
  def roll_over
    unless @course.rollover_due?
      return redirect_to manage_course_path(@course), alert: "Die nächste Periode ist noch nicht bereit."
    end

    new_course = CourseRolloverService.roll_over!(@course)
    if new_course
      redirect_to manage_course_path(new_course), notice: "Nächste Periode (#{new_course.term.name}) wurde erstellt."
    else
      redirect_to manage_course_path(@course), alert: "Die nächste Periode konnte nicht erstellt werden."
    end
  end

  # GET /courses/:id/participant_search?q=...
  def participant_search
    authorize_trainer_or_admin!
    return if performed?

    q = params[:q].to_s.strip
    if q.length >= 2
      @results = Participant.joins(:user)
        .where(
          "LOWER(participants.first_name) LIKE :q OR
           LOWER(participants.last_name) LIKE :q OR
           LOWER(users.email) LIKE :q OR
           LOWER(CONCAT(participants.first_name, ' ', participants.last_name)) LIKE :q",
          q: "%#{q.downcase}%"
        )
        .includes(:user, :course_registrations)
        .limit(10)

      already_registered_ids = @course.course_registrations
        .where.not(status: "storniert")
        .pluck(:participant_id)

      render json: @results.map { |p|
        {
          id: p.id,
          name: "#{p.first_name} #{p.last_name}",
          date_of_birth: p.date_of_birth ? I18n.l(p.date_of_birth) : nil,
          email: p.user&.email,
          already_registered: already_registered_ids.include?(p.id)
        }
      }
    else
      render json: []
    end
  end

  # POST /courses/:id/manual_enroll
  def manual_enroll
    authorize_trainer_or_admin!
    return if performed?

    trial = params[:trial] == "true"
    trial_session_id = params[:trial_session_id]

    if params[:participant_id].present?
      participant = Participant.find(params[:participant_id])
      enroll_participant(participant, trial: trial, trial_session_id: trial_session_id)

    elsif params[:new_family_email].present?
      email = params[:new_family_email].strip.downcase
      email_only = params[:email_only] == "true"

      unless email.match?(URI::MailTo::EMAIL_REGEXP)
        return manual_enroll_form_error("Bitte eine gültige E-Mail-Adresse angeben.")
      end

      if email_only
        first_name = params.dig(:participant, :first_name).to_s.strip
        last_name  = params.dig(:participant, :last_name).to_s.strip

        if first_name.blank? || last_name.blank?
          return manual_enroll_form_error("Bitte Vor- und Nachname angeben.")
        end
      end

      user = User.find_or_initialize_by(email: email)
      reset_password_token = nil

      if user.new_record?
        user.password = Devise.friendly_token[0, 20]
        user.privacy_accepted = true
        user.skip_confirmation!

        unless user.save
          return manual_enroll_form_error("Account konnte nicht erstellt werden: #{user.errors.full_messages.join(', ')}")
        end

        if email_only
          # Kein Passwort-Mail von Devise – der Link steckt stattdessen im
          # ParticipantMailer#complete_profile weiter unten.
          reset_password_token = user.send(:set_reset_password_token)
        else
          user.send_reset_password_instructions
        end
      end

      if email_only
        participant = Participant.new(user: user, first_name: first_name, last_name: last_name)
        participant.save(validate: false)
      else
        p_params = params.require(:participant).permit(
          :first_name, :last_name, :date_of_birth, :gender, :phone_number,
          :ahv_number, :street, :house_number, :zip_code, :city, :country,
          :nationality, :mother_tongue, :js_person_number
        )

        participant = Participant.new(p_params)
        participant.user = user
        participant.phone_number = "000 000 00 00" if participant.phone_number.blank?

        unless participant.save
          @manual_participant = participant
          return manual_enroll_form_error("Teilnehmer konnte nicht erstellt werden: #{participant.errors.full_messages.join(', ')}")
        end
      end

      enroll_participant(participant, trial: trial, trial_session_id: trial_session_id,
        email_only: email_only, reset_password_token: reset_password_token)
    else
      redirect_to manage_course_path(@course), alert: "Bitte Teilnehmer auswählen oder neue Familie erfassen."
    end
  end

  def toggle_talent
    reg = @course.course_registrations.find(params[:registration_id])

    unless current_user.admin? || @course.trainers.exists?(user_id: current_user.id)
      return redirect_to manage_course_path(@course), alert: "Zugriff verweigert."
    end

    unless @course.allows_talent_marking?
      return redirect_to manage_course_path(@course), alert: "Talentmarkierung ist für diesen Kurs nicht aktiviert."
    end

    reg.update!(
      talent_flag: !reg.talent_flag,
      talent_note: params[:talent_note].to_s.strip.presence
    )

    redirect_to manage_course_path(@course), notice: reg.talent_flag? ? "#{reg.participant.first_name} als Talent markiert." : "Talentmarkierung entfernt."
  end

  def send_custom_email
    reg = @course.course_registrations.find(params[:registration_id])
    subject = params[:subject].to_s.strip
    body    = params[:body].to_s.strip

    if subject.blank? || body.blank?
      return redirect_to manage_course_path(@course), alert: "Betreff und Nachricht dürfen nicht leer sein."
    end

    sender = Trainer.find_by(user: current_user) || current_user
    CourseRegistrationMailer.custom_message(reg, subject: subject, body: body, sender: sender).deliver_later
    redirect_to manage_course_path(@course), notice: "E-Mail an #{reg.participant.first_name} #{reg.participant.last_name} wurde gesendet."
  end

  def grant_access
    email = params[:email].to_s.strip.downcase
    user = User.find_by(email: email)

    unless user
      return redirect_to manage_course_path(@course),
        alert: "Kein Benutzer mit der E-Mail-Adresse '#{email}' gefunden.",
        status: :see_other
    end

    grant = CourseAccessGrant.find_or_initialize_by(course: @course, user: user)
    if grant.new_record?
      grant.save!
      CourseAccessMailer.invited(user, @course).deliver_later
      redirect_to manage_course_path(@course),
        notice: "#{user.email} hat jetzt Zugriff auf diesen Kurs.",
        status: :see_other
    else
      redirect_to manage_course_path(@course),
        notice: "#{user.email} hat bereits Zugriff auf diesen Kurs.",
        status: :see_other
    end
  rescue => e
    redirect_to manage_course_path(@course), alert: "Fehler: #{e.message}", status: :see_other
  end

  def revoke_access
    user = User.find(params[:user_id])
    CourseAccessGrant.find_by(course: @course, user: user)&.destroy
    redirect_to manage_course_path(@course),
      notice: "Zugriff für #{user.email} wurde entfernt.",
      status: :see_other
  rescue ActiveRecord::RecordNotFound
    redirect_to manage_course_path(@course), alert: "Benutzer nicht gefunden.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_course
      @course = Course.find(params.expect(:id))
    end

    # Legt beim Erstellen/Bearbeiten eines Kurses (falls Wochentag(e) im Formular gewählt
    # wurden) fehlende Trainingssessions an – erspart den separaten "Trainings generieren"-
    # Schritt. Bereits vorhandene Termine werden übersprungen (siehe generate_training_sessions).
    def generate_training_sessions_from_form(course)
      weekdays = Array(params[:weekdays]).map(&:to_i)
      return if weekdays.empty? || course.default_start_hour.blank? || course.start_date.blank? || course.end_date.blank?

      start_uhrzeit = "#{course.default_start_hour}:#{format('%02d', course.default_start_minute.to_i)}"
      end_uhrzeit   = course.default_end_hour.present? ? "#{course.default_end_hour}:#{format('%02d', course.default_end_minute.to_i)}" : nil

      holiday_ids = Holiday.where(holiday_type_id: course.holiday_type_ids)
                            .where("start_date <= ? AND end_date >= ?", course.end_date, course.start_date)
                            .pluck(:id)

      generate_training_sessions(
        course,
        weekdays: weekdays,
        start_uhrzeit: start_uhrzeit,
        end_uhrzeit: end_uhrzeit,
        holiday_ids: holiday_ids,
        extra_holidays: parse_extra_holidays(params[:extra_holidays])
      )
    end

    # Erstellt TrainingSessions für jeden gewählten Wochentag im Kurszeitraum,
    # überspringt Ferien (DB + manuell) und bereits vorhandene Termine.
    def generate_training_sessions(course, weekdays:, start_uhrzeit:, end_uhrzeit:, holiday_ids: [], extra_holidays: [])
      holidays = Holiday.where(id: holiday_ids)
      sh, sm = start_uhrzeit.split(":").map(&:to_i)
      eh, em = end_uhrzeit&.split(":")&.map(&:to_i)

      created = 0
      skipped = 0
      current_date = course.start_date.to_date
      end_date     = course.end_date.to_date

      while current_date <= end_date
        if weekdays.include?(current_date.wday)
          is_holiday = holidays.any? { |h| current_date >= h.start_date && current_date <= h.end_date } ||
                       extra_holidays.any? { |h| current_date >= h[:start_date] && current_date <= h[:end_date] }
          exists = course.training_sessions.where("start_time::date = ?", current_date).exists?

          if is_holiday || exists
            skipped += 1
          else
            full_start = current_date.in_time_zone.change(hour: sh, min: sm)
            full_end   = eh ? current_date.in_time_zone.change(hour: eh, min: em) : nil
            course.training_sessions.create!(start_time: full_start, end_time: full_end)
            created += 1
          end
        end
        current_date += 1.day
      end

      { created: created, skipped: skipped }
    end

    def parse_extra_holidays(raw)
      Array(raw&.values).filter_map do |h|
        next unless h[:start_date].present? && h[:end_date].present?
        { start_date: Date.parse(h[:start_date]), end_date: Date.parse(h[:end_date]) }
      rescue ArgumentError
        nil
      end
    end

    # Only allow a list of trusted parameters through.
    def course_params
      params.require(:course).permit(:title, :category, :description, :start_date, :end_date, :term_id, :public_registration_days, :auto_rollover, :location, :location_address, :has_payment, :price_chf, :training_value_chf, :discounts_enabled, :sibling_price_chf, :second_course_price_chf, :youth_price_chf, :youth_max_age, :has_ticketing, :is_js_training, :registration_mode, :abo_size, :max_participants, :min_age, :max_age, :requires_ahv_number, :requires_js_person_number, :requires_nationality, :requires_mother_tongue, :requires_zip_code, :requires_city, :requires_country, :requires_street, :default_start_hour, :default_start_minute, :default_end_hour, :default_end_minute, :allows_trial, :enable_waitlist, :restricted, :allows_talent_marking, :email_note, trainer_ids: [], payment_methods: [], holiday_type_ids: [])
    end

    # Stuft nach einer Kapazitätserhöhung Wartelisten-Anmeldungen hoch.
    # Wird nur aktiv, wenn eine Warteliste geführt wird und die neue (höhere)
    # max_participants gesetzt ist. Im Single-Session-Modus ("pro_training")
    # wird die Warteliste pro Termin geführt – daher pro betroffene Session
    # einzeln hochstufen; sonst Semester-Modus mit training_session_id: nil.
    def promote_waitlist_after_capacity_increase(old_max)
      return unless @course.enable_waitlist?
      return if @course.max_participants.blank?
      return unless old_max.blank? || @course.max_participants > old_max

      if @course.registration_type == "pro_training"
        session_ids = @course.course_registrations
                             .where(status: "warteliste")
                             .where.not(training_session_id: nil)
                             .distinct
                             .pluck(:training_session_id)
        session_ids.each do |sid|
          WaitlistPromotionService.promote_next_from_waitlist(@course, training_session_id: sid)
        end
      else
        WaitlistPromotionService.promote_next_from_waitlist(@course)
      end
    end

    def derive_registration_type(registration_mode)
      case registration_mode
      when "single_session" then "pro_training"
      when "jahreskurs"     then "jahreskurs"
      when "quartal"        then "quartal"
      when "abo"            then "abo"
      else "semester"
      end
    end

    def authorize_trainer_or_admin!
      return if current_user&.admin?

      trainer = Trainer.find_by(user: current_user)
      course_trainer = @course.course_trainers.find_by(trainer: trainer)

      unless course_trainer&.can_manually_enroll?
        redirect_to manage_course_path(@course),
          alert: "Du hast keine Berechtigung, Kinder manuell anzumelden."
      end
    end

    def save_trainer_permissions(course)
      permission_params = params.dig(:course, :trainer_permissions)
      return unless permission_params.is_a?(ActionController::Parameters)

      permission_params.each do |trainer_id, perms|
        ct = course.course_trainers.find_by(trainer_id: trainer_id.to_i)
        next unless ct
        ct.update_columns(can_manually_enroll: perms[:can_manually_enroll] == "1")
      end

      # Trainers assigned but not in trainer_permissions → reset to false
      assigned_ids = Array(params.dig(:course, :trainer_ids)).map(&:to_i).reject(&:zero?)
      course.course_trainers.where(trainer_id: assigned_ids).each do |ct|
        unless permission_params.key?(ct.trainer_id.to_s)
          ct.update_columns(can_manually_enroll: false)
        end
      end
    end

    def manual_enroll_form_error(message)
      @manual_participant ||= Participant.new(country: "CH", nationality: "CH", mother_tongue: "DE")
      @show_manual_create_panel = true
      set_manage_view_ivars
      flash.now[:alert] = message
      render :manage, status: :unprocessable_entity
    end

    # Von `manage` sowie jedem Fehlerpfad benötigt, der die manage-View erneut
    # rendert (siehe manual_enroll_form_error und den Teilnehmer-Save-Fehler unten).
    def set_manage_view_ivars
      # Zielkurse für die Admin-Verschiebe-Funktion (alle Kurse, kategorienübergreifend).
      @move_target_courses = Course.order(:category, :title).to_a if current_user&.admin?
      @trial_sessions = if @course.allows_trial?
        @course.training_sessions.where(is_canceled: false).not_past.order(:start_time)
      else
        []
      end
    end

    def enroll_participant(participant, trial: false, trial_session_id: nil, email_only: false, reset_password_token: nil)
      if @course.course_registrations.where(participant: participant).where.not(status: "storniert").exists?
        return redirect_to manage_course_path(@course),
          alert: "#{participant.first_name} ist bereits für diesen Kurs angemeldet."
      end

      return enroll_participant_as_trial(participant, trial_session_id) if trial

      bestaetigte = @course.course_registrations.where(status: CourseRegistration::OCCUPYING_STATUSES).distinct.count(:participant_id)
      status = if @course.max_participants.present? && bestaetigte >= @course.max_participants
        "warteliste"
      else
        "bestätigt"
      end

      abo_remaining_entries = params[:abo_remaining_entries].presence

      reg = CourseRegistration.new(
        course: @course,
        participant: participant,
        status: status,
        payment_cleared: false,
        holiday_deduction_claimed: false
      )

      if @course.abo?
        reg.abo_entries_total = abo_remaining_entries ? abo_remaining_entries.to_i : @course.abo_size
        reg.abo_entries_used  = 0
        reg.payment_cleared = true if abo_remaining_entries
      end

      if reg.save(validate: false)
        # E-Mail-only-Anmeldung: Platzhalter-Teilnehmer hat noch kein Geburtsdatum/
        # Adresse/etc. – statt der Bestätigungsmail geht ein Link zum Ergänzen raus.
        # Die reguläre Bestätigungsmail wird nachgereicht, sobald die Familie das
        # Profil selbst vervollständigt hat (siehe participants_controller#update).
        if email_only
          ParticipantMailer.complete_profile(participant, @course, reset_password_token: reset_password_token).deliver_later
        elsif abo_remaining_entries
          CourseRegistrationMailer.abo_imported(reg).deliver_later
        else
          CourseRegistrationMailer.confirmation(reg).deliver_later
        end

        name = "#{participant.first_name} #{participant.last_name}"
        msg = status == "warteliste" ?
          "#{name} wurde auf die Warteliste gesetzt." :
          "#{name} wurde erfolgreich angemeldet."
        msg += " Die Familie erhält eine E-Mail, um die restlichen Angaben zu ergänzen." if email_only
        redirect_to manage_course_path(@course), notice: msg
      else
        redirect_to manage_course_path(@course),
          alert: "Anmeldung fehlgeschlagen: #{reg.errors.full_messages.join(', ')}"
      end
    end

    def enroll_participant_as_trial(participant, trial_session_id)
      unless @course.allows_trial?
        return redirect_to manage_course_path(@course), alert: "Schnuppern ist für diesen Kurs nicht möglich."
      end

      # Wie beim Eltern-Self-Service: bei Drop-In-Kursen (single_session) legt die
      # gewählte Session direkt training_session_id fest (Kapazität wird pro Session
      # gezählt); bei Semesterkursen ist es eine separate trial_session (Kapazität
      # gilt kursweit, das Schnuppertraining bestimmt nur die 7-Tage-Frist).
      training_session_id_for_capacity = nil
      trial_session = nil

      if @course.registration_mode == "single_session"
        session = @course.training_sessions.find_by(id: trial_session_id)
        if session.nil? || session.is_canceled? || session.past?
          return redirect_to manage_course_path(@course), alert: "Bitte ein gültiges Training auswählen."
        end
        training_session_id_for_capacity = session.id
      else
        trial_session = @course.training_sessions.find_by(id: trial_session_id)
        if trial_session.nil? || trial_session.is_canceled? || trial_session.past?
          return redirect_to manage_course_path(@course), alert: "Bitte ein gültiges Schnuppertraining auswählen."
        end
      end

      status = nil
      reg = nil
      full = false

      Course.find(@course.id).with_lock do
        belegte = if training_session_id_for_capacity
          @course.course_registrations
                 .where(status: CourseRegistration::OCCUPYING_STATUSES, training_session_id: training_session_id_for_capacity)
                 .distinct.count(:participant_id)
        else
          @course.course_registrations.where(status: CourseRegistration::OCCUPYING_STATUSES).distinct.count(:participant_id)
        end

        if @course.max_participants.present? && belegte >= @course.max_participants
          if @course.enable_waitlist?
            status = "warteliste"
          else
            full = true
          end
        else
          status = "schnuppern"
        end

        unless full
          reg = CourseRegistration.new(
            course: @course,
            participant: participant,
            status: status,
            trial_session: trial_session,
            training_session_id: training_session_id_for_capacity,
            payment_cleared: false,
            holiday_deduction_claimed: false
          )
          reg.save(validate: false)
        end
      end

      return redirect_to manage_course_path(@course), alert: "Der Kurs ist voll." if full

      if reg.persisted?
        CourseRegistrationMailer.confirmation(reg).deliver_later
        msg = status == "warteliste" ?
          "#{participant.first_name} wurde auf die Warteliste gesetzt." :
          "#{participant.first_name} wurde zum Schnuppern angemeldet."
        redirect_to manage_course_path(@course), notice: msg
      else
        redirect_to manage_course_path(@course),
          alert: "Anmeldung fehlgeschlagen: #{reg.errors.full_messages.join(', ')}"
      end
    end

    def provision_new_trainer(course)
      return if params[:new_trainer_email].blank?

      email = params[:new_trainer_email].strip.downcase
      user = User.find_or_initialize_by(email: email)
      if user.new_record?
        user.password = Devise.friendly_token[0, 20]
        user.privacy_accepted = true
        user.skip_confirmation!
        user.save!
        user.send_reset_password_instructions
      end
      trainer = Trainer.find_or_create_by(user: user) do |t|
        t.phone = params[:new_trainer_phone].presence
      end
      course.trainers << trainer unless course.trainers.include?(trainer)
    rescue => e
      Rails.logger.error "[CoursesController] Trainer-Erstellung fehlgeschlagen: #{e.message}"
    end
end
