# Wiederverwendbare Ferien-Kategorie (z.B. "Herbstferien"), unter der jedes
# Jahr eine neue Holiday-Instanz mit den konkreten Daten erfasst wird.
# Kurse wählen HolidayTypes aus, die die automatische Trainings-Generierung
# (Erstellung & Rollover) überspringen soll (siehe Course#holiday_types).
class HolidayType < ApplicationRecord
  has_many :holidays, dependent: :destroy
  has_and_belongs_to_many :courses

  validates :name, presence: true, uniqueness: true
end
