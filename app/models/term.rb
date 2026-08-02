# Ein Term ist ein fest definierter Datumsbereich (z.B. "HS2026", "FS2027"),
# den mehrere Kurse referenzieren können.
#
# WICHTIG: nicht zu verwechseln mit Course#registration_mode ("semester"/
# "quartal") – das beschreibt nur die Anmelde-Kadenz (wie oft sich
# Teilnehmende neu anmelden müssen), keinen Datumsbereich. Ein Term hier ist
# rein ein Zeitraum-Objekt und wird aktuell nur zur Zuordnung am Kurs
# angeboten – er bestimmt (noch) nicht automatisch Start-/Enddatum des Kurses.
class Term < ApplicationRecord
  has_many :courses, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :start_date, :end_date, presence: true
  validate :end_date_after_start_date

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?
    errors.add(:end_date, "muss nach dem Startdatum liegen") if end_date < start_date
  end
end
