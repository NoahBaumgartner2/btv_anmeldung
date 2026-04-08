class Course < ApplicationRecord
  has_many :course_registrations, dependent: :destroy
  has_many :participants, through: :course_registrations
  has_many :course_trainers, dependent: :destroy
  has_many :trainers, through: :course_trainers
  has_many :training_sessions, dependent: :destroy

  # Verfügbare Zahlungsmethoden (Stripe-Bezeichnungen → Anzeigenamen)
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

  # Gibt die Symbole der Pflichtfelder zurück, die für diesen Kurs aktiviert sind
  def required_participant_fields
    CONFIGURABLE_REQUIRED_FIELDS.keys.select { |field| self["requires_#{field}"] }
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
end
