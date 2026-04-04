class Course < ApplicationRecord
  has_many :course_registrations, dependent: :destroy
  has_many :participants, through: :course_registrations
  has_many :course_trainers, dependent: :destroy
  has_many :trainers, through: :course_trainers
  has_many :training_sessions, dependent: :destroy

  # Konfigurierbare Pflichtfelder: Symbol → Anzeigename
  CONFIGURABLE_REQUIRED_FIELDS = {
    ahv_number: "AHV-Nummer"
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
end
