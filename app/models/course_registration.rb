class CourseRegistration < ApplicationRecord
  TRIAL_STATUS = "schnuppern"

  # Stati, die einen Platz belegen (maßgeblich für Kapazitäts- und Warteliste-Prüfungen).
  # Bewusst OHNE "ausstehend": ein offener/abgebrochener Checkout darf keinen Platz
  # blockieren – sonst landen echte Teilnehmer fälschlich auf der Warteliste, obwohl der
  # Kurs nicht voll ist. Beim Bezahlen ist ohnehin nur "bestätigt"/"schnuppern" maßgeblich
  # (siehe PaymentSyncService.mark_paid!). "platz_frei" zählt mit, weil ein angebotener
  # Wartelistenplatz reserviert bleiben muss (kein Doppelvergeben).
  OCCUPYING_STATUSES = %w[bestätigt schnuppern platz_frei].freeze

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
  validate :no_duplicate_semester_registration, on: :create, unless: :abo_booking?
  validate :training_session_bookable, on: :create
  validate :trial_session_bookable, on: :create

  before_save :set_payment_expiry, if: -> { will_save_change_to_status?(to: "ausstehend") }
  before_save :set_trial_expiry,
    if: -> { will_save_change_to_status?(to: TRIAL_STATUS) && trial_expires_at.nil? }

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
      .where("training_sessions.start_time > ?", Time.current)
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
      .where("training_sessions.start_time > ?", Time.current)
      .where.not(id: already_booked_ids)
      .includes(:course)
      .order("training_sessions.start_time")
  end

  private

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
    elsif trial_session.start_time <= Time.current
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

    existing = CourseRegistration.where(
      participant_id: participant_id,
      course_id: course_id
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
    elsif training_session.start_time <= Time.current
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
