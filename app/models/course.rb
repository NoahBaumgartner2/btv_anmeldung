class Course < ApplicationRecord
  has_many :course_registrations, dependent: :destroy
  has_many :participants, through: :course_registrations
  has_many :course_trainers, dependent: :destroy
  has_many :trainers, through: :course_trainers
  has_many :training_sessions, dependent: :destroy

  # Verfügbare Zahlungsmethoden (→ Anzeigenamen)
  PAYMENT_METHODS = {
    "card"  => "Kreditkarte / Debitkarte",
    "twint" => "TWINT"
  }.freeze

  before_save :clean_payment_methods

  # Gibt die tatsächlich nutzbaren Zahlungsmethoden zurück (bereinigt, mit Fallback)
  def effective_payment_methods
    m = (payment_methods.presence || []).select { |v| PAYMENT_METHODS.key?(v) }
    m.any? ? m : ["card"]
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

  def price_display
    return "Kostenlos" unless has_payment? && price_cents
    "CHF #{price_chf}"
  end

  private

  def clean_payment_methods
    self.payment_methods = (payment_methods || []).reject(&:blank?).select { |v| PAYMENT_METHODS.key?(v) }
    self.payment_methods = ["card"] if payment_methods.empty?
  end

  def max_age_must_be_greater_than_or_equal_to_min_age
    return if min_age.blank? || max_age.blank?
    errors.add(:max_age, "muss grösser oder gleich dem Mindestalter sein") if max_age < min_age
  end
end
