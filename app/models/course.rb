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
end
