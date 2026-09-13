# Nachforderung: ein zusätzlicher Betrag, den ein Admin nachträglich zu einer
# bereits bestehenden Kursanmeldung einfordert (z.B. Korrektur eines fälschlich
# angewendeten Rabatts). Bewusst als eigenes, schlankes Modell statt über
# CourseRegistration/DiscountCalculator - eine Registration bildet genau EINEN
# Kurspreis ab, keine nachträglichen Zusatzbeträge. Zahlung läuft über denselben
# SumUp-Checkout-Mechanismus wie course_registrations (siehe
# SupplementaryChargesController), aber unabhängig von PaymentSyncService/
# CourseRegistration-Statuslogik (Warteliste, Abo-Merge etc. sind hier irrelevant).
class SupplementaryCharge < ApplicationRecord
  belongs_to :participant
  belongs_to :course
  belongs_to :created_by, class_name: "User", optional: true

  STATUSES = %w[offen bezahlt storniert].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :description, presence: true

  def amount_display
    "CHF #{format('%.2f', amount_cents / 100.0)}"
  end

  def paid?
    status == "bezahlt"
  end

  def payable?
    status == "offen"
  end
end
