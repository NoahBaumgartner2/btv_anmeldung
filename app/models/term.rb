# Ein Term ist ein fest definierter Datumsbereich (z.B. "HS2026", "FS2027"),
# den mehrere Kurse referenzieren können.
#
# WICHTIG: nicht zu verwechseln mit Course#registration_mode ("semester"/
# "quartal") – das beschreibt nur die Anmelde-Kadenz (wie oft sich
# Teilnehmende neu anmelden müssen), keinen Datumsbereich.
#
# `kind` (semester/quartal) legt fest, zu welcher Abfolge ein Term gehört –
# damit lässt sich "der nächste Term nach diesem" bestimmen (z.B. nach
# HS2026 kommt FS2027), was RolloverCoursePeriodsJob für die automatische
# Kurs-Verlängerung nutzt.
#
# `priority_registration_date` ist das Datum, ab dem für diesen Term die
# Anmeldung für bereits im Vorgänger-Kurs angemeldete Teilnehmende öffnet
# (siehe Course#rollover_due? und Course#registration_window_open_for?).
# Wird einmal pro Term gepflegt (z.B. bei HS2026), statt bei jedem Kurs neu.
class Term < ApplicationRecord
  KINDS = %w[semester quartal].freeze

  has_many :courses, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :start_date, :end_date, presence: true
  validates :kind, presence: true, inclusion: { in: KINDS }
  validate :end_date_after_start_date

  # Der chronologisch nächste Term derselben Art (z.B. nach HS2026 -> FS2027).
  def next_term
    Term.where(kind: kind).where("start_date > ?", start_date).order(:start_date).first
  end

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?
    errors.add(:end_date, "muss nach dem Startdatum liegen") if end_date < start_date
  end
end
