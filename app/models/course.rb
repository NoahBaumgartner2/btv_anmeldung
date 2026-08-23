class Course < ApplicationRecord
  # Optionale Zuordnung zu einem Term (Semester/Quartal-Datumsbereich, z.B.
  # "HS2026"). Nicht zu verwechseln mit registration_mode ("semester"/
  # "quartal"), das nur die Anmelde-Kadenz beschreibt.
  #
  # Kurse mit gesetztem term können automatisch verlängert werden: sobald die
  # Vorlauf-Schwelle erreicht ist, erstellt RolloverCoursePeriodsJob via
  # CourseRolloverService einen Nachfolge-Kurs für term.next_term und verweist
  # per previous_course auf diesen (verhindert doppeltes Auslösen).
  belongs_to :term, optional: true
  belongs_to :previous_course, class_name: "Course", optional: true
  has_and_belongs_to_many :holiday_types
  has_one :next_course, class_name: "Course", foreign_key: :previous_course_id, dependent: :nullify, inverse_of: :previous_course

  has_many :course_registrations, dependent: :destroy
  has_many :participants, through: :course_registrations
  has_many :course_trainers, dependent: :destroy
  has_many :trainers, through: :course_trainers
  has_many :training_sessions, dependent: :destroy
  has_many :course_access_grants, dependent: :destroy
  has_many :permitted_users, through: :course_access_grants, source: :user

  # Verfügbare Zahlungsmethoden (→ Anzeigenamen)
  PAYMENT_METHODS = {
    "card" => "Kreditkarte / Debitkarte"
  }.freeze

  before_save :clean_payment_methods
  before_save :clear_dates_for_abo
  before_save :clear_rollover_fields_without_term

  # Gibt die tatsächlich nutzbaren Zahlungsmethoden zurück (bereinigt, mit Fallback)
  def effective_payment_methods
    m = (payment_methods.presence || []).select { |v| PAYMENT_METHODS.key?(v) }
    m.any? ? m : [ "card" ]
  end

  # Konfigurierbare Pflichtfelder: Symbol → Anzeigename
  CONFIGURABLE_REQUIRED_FIELDS = {
    ahv_number:       "AHV-Nummer",
    js_person_number: "J+S Personennummer",
    nationality:      "Nationalität",
    mother_tongue:    "Muttersprache",
    zip_code:         "PLZ",
    city:             "Ort",
    country:          "Land",
    street:           "Strasse"
  }.freeze

  # Gibt die Symbole der Pflichtfelder zurück, die für diesen Kurs aktiviert sind.
  # Bei J+S-Kursen ist die AHV-Nummer immer Pflicht.
  def required_participant_fields
    fields = CONFIGURABLE_REQUIRED_FIELDS.keys.select { |field| self["requires_#{field}"] }
    fields |= [ :ahv_number ] if is_js_training?
    fields
  end

  # ── Altersbeschränkung ─────────────────────────────────────────────────────
  validates :min_age, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 120 }, allow_nil: true
  validates :max_age, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 120 }, allow_nil: true
  validate  :max_age_must_be_greater_than_or_equal_to_min_age

  def age_restricted?
    min_age.present? || max_age.present?
  end

  # Referenzdatum für die Altersberechnung: Kursstart, sonst heute
  def age_reference_date
    (start_date || Date.current).to_date
  end

  # Prüft, ob ein Teilnehmer altersmässig für den Kurs zugelassen ist
  def accepts_participant_age?(participant)
    return true unless age_restricted?
    return false unless participant&.date_of_birth

    age = participant.age_at(age_reference_date)
    return false if min_age.present? && age < min_age
    return false if max_age.present? && age > max_age
    true
  end

  # Hübsches Label für die Altersspanne
  def age_range_label
    return nil unless age_restricted?
    if min_age.present? && max_age.present?
      "#{min_age}–#{max_age} Jahre"
    elsif min_age.present?
      "ab #{min_age} Jahren"
    else
      "bis #{max_age} Jahre"
    end
  end

  # Price helpers: store as Rappen (cents), display in CHF
  def price_chf
    cents = read_attribute(:price_cents)
    return "" unless cents
    format("%.2f", cents / 100.0)
  end

  def price_chf=(value)
    self.price_cents = value.presence ? (value.to_f * 100).round : nil
  end

  def training_value_chf
    cents = read_attribute(:training_value_cents)
    return "" unless cents
    format("%.2f", cents / 100.0)
  end

  def training_value_chf=(value)
    self.training_value_cents = value.presence ? (value.to_f * 100).round : nil
  end

  def price_display
    return I18n.t("courses.free") unless has_payment? && price_cents
    "CHF #{price_chf}"
  end

  # Abzug (in Rappen) für eine Anmeldung, die erst nach Kursstart erfolgt -
  # das erste bereits stattgefundene Training zählt noch normal, ab jedem
  # weiteren wird der Trainingswert abgezogen (siehe DiscountCalculator, das
  # dieselbe Methode für die tatsächliche Registration nutzt).
  def late_registration_deduction_cents(at: Time.current)
    return 0 unless allows_late_registration_deduction? && training_value_cents.present? && training_value_cents.positive?

    passed_sessions = training_sessions.where(is_canceled: false).where("start_time <= ?", at).count
    billable_sessions = [ passed_sessions - 1, 0 ].max
    billable_sessions * training_value_cents
  end

  # Der Preis, den ein *neuer* Teilnehmer aktuell zahlen würde (ohne
  # personenbezogene Rabatte wie Geschwister/Zweitkurs - siehe
  # DiscountCalculator für die vollständige, registrierungsbezogene Version).
  def effective_price_cents(at: Time.current)
    return price_cents.to_i unless has_payment? && price_cents.present?
    [ price_cents - late_registration_deduction_cents(at: at), 0 ].max
  end

  def effective_price_display
    return I18n.t("courses.free") unless has_payment? && price_cents
    "CHF #{format('%.2f', effective_price_cents / 100.0)}"
  end

  # ── Preisreduktion (Geschwister / Zweitkurs) ───────────────────────────────
  validate :discount_prices_must_be_valid, if: :discounts_enabled?

  def sibling_price_chf
    cents = read_attribute(:sibling_price_cents)
    return "" unless cents
    format("%.2f", cents / 100.0)
  end

  def sibling_price_chf=(value)
    self.sibling_price_cents = value.presence ? (value.to_f * 100).round : nil
  end

  def second_course_price_chf
    cents = read_attribute(:second_course_price_cents)
    return "" unless cents
    format("%.2f", cents / 100.0)
  end

  def second_course_price_chf=(value)
    self.second_course_price_cents = value.presence ? (value.to_f * 100).round : nil
  end

  def sibling_price_display
    return nil unless sibling_price_cents
    "CHF #{sibling_price_chf}"
  end

  def second_course_price_display
    return nil unless second_course_price_cents
    "CHF #{second_course_price_chf}"
  end

  # ── Jugendpreis (altersbasierter Preis-Tier) ───────────────────────────────
  def youth_price_chf
    cents = read_attribute(:youth_price_cents)
    return "" unless cents
    format("%.2f", cents / 100.0)
  end

  def youth_price_chf=(value)
    self.youth_price_cents = value.presence ? (value.to_f * 100).round : nil
  end

  def youth_price_display
    return nil unless youth_price_cents
    "CHF #{youth_price_chf}"
  end

  def registration_mode_label
    return nil unless registration_mode.present?
    I18n.t("courses.registration_modes.#{registration_mode}", default: registration_mode.humanize)
  end

  def registration_type_label
    return nil unless registration_type.present?
    I18n.t("courses.registration_types.#{registration_type}", default: registration_type.humanize)
  end

  def abo?
    registration_mode == "abo"
  end

  # Abo-Kurs derselben Kategorie, in dem ein automatischer Ausgleichs-Eintritt
  # (siehe #grant_abo_makeup_entry!) gutgeschrieben wird. Bei mehreren
  # passenden Abo-Kursen wird der zuletzt angelegte gewählt.
  def matching_abo_course
    return nil unless category.present?
    Course.where(category: category, registration_mode: "abo").where.not(id: id).order(created_at: :desc).first
  end

  # Schreibt participant einen kostenlosen Einzel-Abo-Eintritt gut (siehe
  # grants_abo_makeup_entry?): erhöht ein bestehendes Abo derselben Kategorie
  # um 1 Eintritt, oder legt bei Bedarf ein neues Ein-Eintritt-Abo an.
  # No-op ohne passenden Abo-Kurs (z.B. keine Kategorie gesetzt).
  def grant_abo_makeup_entry!(participant)
    target_course = matching_abo_course
    return nil unless target_course

    target_course.with_lock do
      existing_abo = CourseRegistration.where(
        participant_id: participant.id, course_id: target_course.id, status: "bestätigt"
      ).where.not(abo_entries_total: nil).first

      if existing_abo
        existing_abo.increment!(:abo_entries_total, 1)
        existing_abo
      else
        CourseRegistration.create!(
          course: target_course,
          participant: participant,
          status: "bestätigt",
          payment_cleared: true,
          abo_entries_total: 1,
          abo_entries_used: 0
        )
      end
    end
  end

  # Storniert bestehende Abo-Einzelbuchungen (abo_source_registration_id gesetzt)
  # von participant in DIESEM Kurs und erstattet die verbrauchten Abo-Eintritte
  # zurück. Wird nach einer neuen, bestätigten Semesteranmeldung aufgerufen: die
  # Semesteranmeldung deckt die betroffenen Termine jetzt ohnehin ab – ohne
  # diesen Aufruf bliebe der Termin im Profil fälschlich als "per Abo gebucht"
  # markiert und der Abo-Eintritt dauerhaft verbraucht. Gibt die Anzahl der
  # stornierten Buchungen zurück.
  def reclaim_abo_bookings!(participant)
    bookings = CourseRegistration.where(
      participant_id: participant.id, course_id: id
    ).where.not(abo_source_registration_id: nil).where.not(status: "storniert")

    count = 0
    bookings.find_each do |booking|
      booking.with_lock do
        booking.reload
        next if booking.status == "storniert"

        training_session_id = booking.training_session_id
        booking.update!(status: "storniert", cancelled_at: Time.current)
        booking.refund_abo_entry!
        WaitlistPromotionService.promote_next_from_waitlist(self, training_session_id: training_session_id) if training_session_id
        count += 1
      end
    end
    count
  end

  # ── Teilnehmerzählung (zentral, für ALLE Übersichten) ──────────────────────
  # Belegte Plätze = bestätigt + schnuppern + platz_frei (CourseRegistration::OCCUPYING_STATUSES),
  # eindeutig pro Teilnehmer:in. Maßgeblich für jede Teilnehmer-/Kapazitätsanzeige und deckt sich
  # mit der Anmelde-Kapazitätsprüfung. Arbeitet Ruby-seitig auf der (ggf. vorgeladenen) Association,
  # damit kein N+1 entsteht, wenn der Controller course_registrations included.
  #
  # 10er-Abo-Einzelbuchungen (abo_source_registration_id gesetzt) zählen hier NICHT mit:
  # sie belegen nur EINEN einzelnen Termin (siehe TrainingSession#occupied_spots), nicht
  # dauerhaft einen Platz im Kurs. Sonst würde ein einziger Schnuppertermin per Abo den
  # ganzen Kurs für den Rest des Semesters fälschlich als "ausgebucht" markieren.
  def occupied_spots
    course_registrations
      .select { |r| CourseRegistration::OCCUPYING_STATUSES.include?(r.status) && r.abo_source_registration_id.blank? }
      .map(&:participant_id).uniq.size
  end

  # Echte Wartelisten-Einträge, eindeutig pro Teilnehmer:in.
  def waitlist_count
    course_registrations
      .select { |r| r.status == "warteliste" }
      .map(&:participant_id).uniq.size
  end

  def full?
    max_participants.present? && occupied_spots >= max_participants
  end

  def spots_remaining
    return nil if max_participants.blank?
    [ max_participants - occupied_spots, 0 ].max
  end

  # Repräsentative Session für Wochentag/Uhrzeit: nächste kommende,
  # nicht abgesagte Session; Fallback: erste Session überhaupt.
  # Arbeitet Ruby-seitig auf den geladenen Sessions (kein N+1 mit includes).
  def representative_session
    @representative_session ||=
      training_sessions.reject(&:is_canceled)
                       .select { |s| s.start_time.present? }
                       .then { |ss| ss.select { |s| s.start_time > Time.current }.min_by(&:start_time) || ss.min_by(&:start_time) }
  end

  # Sortierschlüssel: [Wochentag (Mo=0 … So=6), Sekunden seit Mitternacht].
  # Kurse ohne Sessions ans Ende.
  def weekly_sort_key
    s = representative_session
    return [ 7, 0 ] unless s
    [ (s.start_time.wday - 1) % 7, s.start_time.seconds_since_midnight.to_i ]
  end

  def accessible_by?(user)
    !restricted? || user&.admin? || permitted_users.include?(user)
  end

  # Der chronologisch nächste Term derselben Art (nil wenn kein Term gesetzt).
  def next_term
    term&.next_term
  end

  # Ist die automatische Verlängerung fällig? (Term gesetzt, nächster Term
  # existiert, noch nicht verlängert, Vorlauf-Datum des nächsten Terms
  # erreicht oder leer.)
  def rollover_due?
    return false if term.blank? || next_term.blank? || next_course.present?
    Date.current >= (next_term.priority_registration_date || next_term.start_date.to_date)
  end

  # Zugriffssperre für automatisch verlängerte Kurse: ohne previous_course
  # (kein Nachfolge-Kurs einer Verlängerung) gilt die normale Anmeldung ohne
  # Einschränkung. Mit previous_course gilt ein zweistufiges Fenster: zuerst
  # nur für Familien mit aktiver Anmeldung im Vorgänger-Kurs (ab
  # term.priority_registration_date), danach für alle (ab
  # term.priority_registration_date + public_registration_days).
  def registration_window_open_for?(user)
    priority_date = term&.priority_registration_date
    return true if previous_course_id.blank? || priority_date.blank?

    public_from = priority_date + public_registration_days.to_i.days
    return true if Date.current >= public_from
    return false if Date.current < priority_date

    previous_course.course_registrations
      .joins(participant: :user)
      .where(users: { id: user&.id })
      .where.not(status: "storniert")
      .exists?
  end

  private

  def clean_payment_methods
    self.payment_methods = (payment_methods || []).reject(&:blank?).select { |v| PAYMENT_METHODS.key?(v) }
    self.payment_methods = [ "card" ] if payment_methods.empty?
  end

  # Abo-Kurse sind durchgehend verfügbar (kein fester Zeitraum).
  def clear_dates_for_abo
    return unless registration_mode == "abo"
    self.start_date = nil
    self.end_date = nil
    self.term_id = nil
  end

  # Eigener Zeitraum (kein Term): automatische Verlängerung ist ohne Term
  # ohnehin nicht möglich (siehe rollover_due?) – die Checkbox wird zusätzlich
  # zurückgesetzt, damit sie nicht "unsichtbar aktiv" bleibt (z.B. wenn im
  # Formular auf "Eigener Zeitraum" gewechselt wird). public_registration_days
  # bleibt unangetastet – das steuert zusammen mit term.priority_registration_date
  # das Registrierungsfenster für previous_course-Nachfolgekurse (siehe
  # registration_window_open_for?).
  def clear_rollover_fields_without_term
    return if term_id.present?
    self.auto_rollover = false
  end

  def max_age_must_be_greater_than_or_equal_to_min_age
    return if min_age.blank? || max_age.blank?
    errors.add(:max_age, "muss grösser oder gleich dem Mindestalter sein") if max_age < min_age
  end

  def discount_prices_must_be_valid
    if sibling_price_cents.blank? && second_course_price_cents.blank?
      errors.add(:base, "Bei aktivierter Preisreduktion muss mindestens ein reduzierter Preis angegeben werden")
    end

    { sibling_price_cents: sibling_price_cents, second_course_price_cents: second_course_price_cents }.each do |attr, cents|
      next if cents.blank?
      if cents.negative?
        errors.add(attr, "darf nicht negativ sein")
      elsif price_cents.present? && cents >= price_cents
        errors.add(attr, "muss kleiner als der Kurspreis sein")
      end
    end
  end
end
