class CourseRegistration < ApplicationRecord
  TRIAL_STATUS = "schnuppern"

  # Stati, die einen Platz belegen (maßgeblich für Kapazitäts- und Warteliste-Prüfungen).
  # Bewusst OHNE "ausstehend": ein offener/abgebrochener Checkout darf keinen Platz
  # blockieren – sonst landen echte Teilnehmer fälschlich auf der Warteliste, obwohl der
  # Kurs nicht voll ist. Beim Bezahlen ist ohnehin nur "bestätigt"/"schnuppern" maßgeblich
  # (siehe PaymentSyncService.mark_paid!). "platz_frei" zählt mit, weil ein angebotener
  # Wartelistenplatz reserviert bleiben muss (kein Doppelvergeben).
  OCCUPYING_STATUSES = %w[bestätigt schnuppern platz_frei].freeze

  # Anmeldungen ohne training_session_id gelten für JEDE Session des Kurses NUR
  # bei Semester-Anmeldungen (Teilnehmer:in kommt wöchentlich). Abo-Pässe
  # (abo_entries_total gesetzt) haben ebenfalls kein training_session_id, sind
  # aber selbst kein Session-Besuch – nur ihre abo_bookings (Kinder mit
  # eigenem training_session_id) gelten für eine bestimmte Session. Ohne diesen
  # Ausschluss würde der Abo-Pass fälschlich bei jeder Session des Kurses als
  # Teilnahme gezählt/angezeigt (siehe #occupied_spots, TrainingSessionsController#show).
  scope :applicable_to_session, ->(session_id) {
    where("training_session_id = ? OR (training_session_id IS NULL AND abo_entries_total IS NULL)", session_id)
  }

  belongs_to :course
  belongs_to :participant
  belongs_to :training_session, optional: true
  belongs_to :trial_session, class_name: "TrainingSession", optional: true
  belongs_to :cancelled_by_trainer, class_name: "Trainer", optional: true,
             inverse_of: :cancelled_registrations
  belongs_to :abo_source, class_name: "CourseRegistration",
             foreign_key: :abo_source_registration_id, optional: true

  has_many :attendances, dependent: :destroy
  has_many :abo_bookings, class_name: "CourseRegistration",
           foreign_key: :abo_source_registration_id, dependent: :nullify

  validate :participant_has_required_fields, on: :create, unless: :abo_booking?
  validate :no_duplicate_single_session_registration, on: :create, unless: :abo_booking?
  # Abo-Pässe (course.abo?) dürfen mehrfach gekauft werden – ein zweiter Kauf wird nach
  # der Zahlung mit dem bestehenden Pass zusammengeführt statt geblockt (siehe
  # #merge_into_existing_abo! und CourseRegistrationsController#create).
  validate :no_duplicate_semester_registration, on: :create, unless: -> { abo_booking? || course&.abo? }
  validate :training_session_bookable, on: :create
  validate :trial_session_bookable, on: :create

  before_save :set_payment_expiry, if: -> { will_save_change_to_status?(to: "ausstehend") }
  before_save :set_trial_expiry,
    if: -> { will_save_change_to_status?(to: TRIAL_STATUS) && trial_expires_at.nil? }
  # Wird ein Abo-Pass storniert (z.B. via trainer_cancel), müssen auch seine noch
  # aktiven Einzelsession-Buchungen (abo_bookings) storniert werden – sonst bleiben
  # sie als "bestätigt" verwaist stehen und blockieren später (Unique-Index auf
  # participant_id+training_session_id) das erneute Buchen derselben Session über
  # einen neuen Abo-Pass mit einem 500er statt einer verständlichen Fehlermeldung.
  after_update :cancel_abo_bookings, if: -> { saved_change_to_status?(to: "storniert") && abo_entries_total.present? }

  def trial?
    status == TRIAL_STATUS
  end

  def payment_required?
    course.has_payment? && course.price_cents.to_i > 0
  end

  # Tatsächlich berechneter Betrag inkl. angewandter Preisreduktion. Wird beim
  # Checkout in applied_price_cents festgehalten; ohne Rabatt gilt der Kurspreis.
  # Maßgeblich für Quittung/Beleg — der Kurspreis allein wäre falsch, sobald ein
  # Jugend-/Geschwister-/Zweitkursrabatt griff (siehe DiscountCalculator).
  def paid_amount_cents
    applied_price_cents || course.price_cents
  end

  def paid_amount_display
    cents = paid_amount_cents
    return I18n.t("courses.free") unless course.has_payment? && cents
    "CHF #{format('%.2f', cents / 100.0)}"
  end

  # Zahlung ist möglich/nötig: Kurs kostenpflichtig, noch nicht bezahlt, und die
  # Anmeldung ist aktiv. "schnuppern" ist bewusst zahlbar: Beim Umwandeln eines
  # Schnupperplatzes in eine reguläre Anmeldung bleibt der Status "schnuppern"
  # (Platz bleibt belegt, 7-Tage-Frist läuft weiter) bis die Zahlung bestätigt
  # ist – wird die Zahlung abgebrochen, geht der Schnupperplatz nicht verloren.
  def payable?
    course.has_payment? && course.price_cents.to_i > 0 &&
      !payment_cleared? && status.in?(%w[ausstehend bestätigt schnuppern])
  end

  # In der Kursverwaltung als "echter" Teilnehmer sichtbar:
  # - Schnuppern ist gratis → immer sichtbar
  # - bestätigt nur, wenn keine Zahlung nötig ODER tatsächlich bezahlt
  def fully_confirmed?
    return true if status == TRIAL_STATUS
    status == "bestätigt" && (!payment_required? || payment_cleared?)
  end

  def refund_already_processed?
    refunded_at.present?
  end

  def trial_expired?
    trial? && (trial_expires_at || created_at + 7.days) < Time.current
  end

  def status_label
    I18n.t("course_registrations.statuses.#{status}", default: status.to_s.humanize)
  end

  def abo_entries_remaining
    return nil unless abo_entries_total.present?
    abo_entries_total - abo_entries_used.to_i
  end

  def abo_exhausted?
    return false unless abo_entries_total.present?
    abo_entries_used.to_i >= abo_entries_total
  end

  def abo_booking?
    abo_source_registration_id.present?
  end

  # Nimmt einen zuvor automatisch gutgeschriebenen Ausgleichseintritt (siehe
  # Course#grant_abo_makeup_entry!) wieder zurück, wenn er noch nicht verbraucht
  # wurde – wird beim Wieder-Anmelden zu einem abgemeldeten Training gebraucht,
  # sonst könnte man sich beliebig oft ab-/wieder anmelden und dabei jedes Mal
  # einen zusätzlichen Abo-Eintritt "farmen". Gibt false zurück (ohne etwas zu
  # ändern), wenn der Eintritt bereits verbraucht ist – der Aufrufer muss die
  # Wieder-Anmeldung dann blockieren.
  def claw_back_makeup_entry!
    with_lock do
      reload
      return false if abo_entries_remaining.to_i <= 0

      new_total = abo_entries_total.to_i - 1
      if new_total.zero? && abo_entries_used.to_i.zero?
        update!(status: "storniert", cancelled_at: Time.current, abo_entries_total: 0)
      else
        update_columns(abo_entries_total: new_total, updated_at: Time.current)
      end
    end
    true
  end

  # Nach einem (erneuten) Abo-Kauf: existiert für dieselbe Person im selben Kurs
  # bereits ein anderer aktiver Abo-Pass, werden die neu gekauften Eintritte dort
  # aufsummiert (z.B. 3 verbleibende + neues 10er-Abo = 13) und diese Anmeldung
  # sofort storniert – Eltern/Admins sehen so weiterhin nur einen Abo-Pass pro Kurs
  # statt zwei getrennter Zeilen. Gibt den Ziel-Pass zurück, wenn zusammengeführt
  # wurde, sonst nil. Nur für frisch bezahlte/bestätigte Abo-Pässe selbst aufrufen
  # (nicht für Session-Buchungen, siehe abo_booking?).
  #
  # WICHTIG: setzt NIE status: "bestätigt" auf sich selbst (auch nicht kurzzeitig) –
  # ein DB-Unique-Index (index_course_registrations_unique_active) erlaubt nur eine
  # aktive Anmeldung pro Person/Kurs. extra_attrs (z.B. payment_cleared, sumup_*)
  # werden zusammen mit dem Storno in einem einzigen update! gesetzt.
  def merge_into_existing_abo!(**extra_attrs)
    return nil unless course.abo? && !abo_booking? && abo_entries_total.present?

    target = CourseRegistration
      .where(participant_id: participant_id, course_id: course_id, status: "bestätigt")
      .where.not(id: id)
      .first
    return nil unless target

    target.increment!(:abo_entries_total, abo_entries_total.to_i)
    update!(**extra_attrs, status: "storniert", cancelled_at: Time.current)
    target
  end

  def refund_abo_entry!
    return unless abo_source.present?
    abo_source.with_lock do
      abo_source.reload
      new_used = [ abo_source.abo_entries_used.to_i - 1, 0 ].max
      abo_source.update_columns(abo_entries_used: new_used, updated_at: Time.current)
    end
  end

  def abo_booked_session_ids
    abo_bookings.where.not(status: "storniert").pluck(:training_session_id).compact
  end

  def displayable_abo_sessions
    return [] unless course.abo? && course.category.present?

    TrainingSession
      .joins(:course)
      .where(courses: { category: course.category })
      .where(is_canceled: false)
      .not_past
      .includes(:course)
      .order("training_sessions.start_time")
  end

  def bookable_abo_sessions
    return [] unless course.abo? && course.category.present?
    return [] if abo_exhausted?

    already_booked_ids = abo_bookings
      .where.not(status: "storniert")
      .pluck(:training_session_id)
      .compact

    TrainingSession
      .joins(:course)
      .where(courses: { category: course.category })
      .where(is_canceled: false)
      .not_past
      .where.not(id: already_booked_ids)
      .includes(:course)
      .order("training_sessions.start_time")
  end

  private

  # Siehe after_update-Callback oben: storniert alle noch aktiven Kinder-Buchungen
  # dieses Abo-Passes (kein Refund nötig, der Pass selbst ist ja bereits storniert).
  def cancel_abo_bookings
    abo_bookings.where.not(status: "storniert").find_each do |booking|
      course = booking.course
      training_session_id = booking.training_session_id
      booking.update!(status: "storniert", cancelled_at: Time.current)
      WaitlistPromotionService.promote_next_from_waitlist(course, training_session_id: training_session_id) if training_session_id
    end
  end

  # Zahlungsfrist beim Statuswechsel zu "ausstehend":
  # - Stammt die Anmeldung aus einem Schnupperplatz (trial_expires_at gesetzt),
  #   gilt die zugesicherte Frist "Schnuppertraining + 7 Tage". Eine 48h-Untergrenze
  #   verhindert eine sofortige Stornierung, falls die Konversion erst spät erfolgt.
  # - Reguläre Anmeldungen ohne Schnupperhintergrund erhalten die übliche 48h-Frist.
  def set_payment_expiry
    self.payment_expires_at =
      if trial_expires_at.present?
        [ trial_expires_at, 48.hours.from_now ].max
      else
        48.hours.from_now
      end
  end

  # Die 7-Tage-Frist beginnt erst NACH dem Schnuppertraining.
  # Bei Drop-In-Trials wird die bereits gesetzte training_session als Basis genutzt.
  def set_trial_expiry
    base = (trial_session || training_session)&.start_time
    self.trial_expires_at = (base || Time.current) + 7.days
  end

  def trial_session_bookable
    return if trial_session.blank?

    if trial_session.course_id != course_id
      errors.add(:base, I18n.t("course_registrations.errors.trial_session_wrong_course"))
    elsif trial_session.is_canceled?
      errors.add(:base, I18n.t("course_registrations.errors.session_cancelled"))
    elsif trial_session.past?
      errors.add(:base, I18n.t("course_registrations.errors.session_in_past"))
    end
  end

  def no_duplicate_single_session_registration
    return unless course&.registration_mode == "single_session" && training_session_id.present? && participant_id.present?

    already_registered = CourseRegistration.where(
      participant_id: participant_id,
      course_id: course_id,
      training_session_id: training_session_id
    ).where.not(status: [ "storniert", "ausstehend" ]).exists?

    errors.add(:base, I18n.t("course_registrations.errors.duplicate_session")) if already_registered
  end

  def no_duplicate_semester_registration
    return if course.blank? || participant_id.blank?
    return if course.registration_mode == "single_session"

    # Über ein Abo gebuchte einzelne Sessions (abo_source_registration_id gesetzt)
    # teilen sich den course_id mit dem Semesterkurs, sind aber keine vollwertige
    # Anmeldung – zählen daher NICHT als Duplikat, sonst kann sich niemand mehr
    # für das Semester anmelden, nachdem er/sie schon einzelne Trainings per Abo
    # besucht hat.
    existing = CourseRegistration.where(
      participant_id: participant_id,
      course_id: course_id,
      abo_source_registration_id: nil
    ).where.not(status: [ "storniert", "ausstehend" ]).first

    return unless existing

    if existing.status == TRIAL_STATUS
      errors.add(:base, I18n.t("course_registrations.errors.duplicate_schnuppern"))
    else
      errors.add(:base, I18n.t("course_registrations.errors.duplicate_registration"))
    end
  end

  def training_session_bookable
    return unless training_session.present?

    if training_session.is_canceled?
      errors.add(:base, I18n.t("course_registrations.errors.session_cancelled"))
    elsif training_session.past?
      errors.add(:base, I18n.t("course_registrations.errors.session_in_past"))
    end
  end

  def participant_has_required_fields
    return unless course && participant

    missing = participant.missing_fields_for(course)
    missing.each do |field|
      errors.add(:base, I18n.t("course_registrations.errors.missing_field",
                               field: Participant.field_label(field),
                               name: "#{participant.first_name} #{participant.last_name}"))
    end
  end
end
