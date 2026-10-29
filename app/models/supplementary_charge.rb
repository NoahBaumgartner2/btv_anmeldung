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

  def mark_paid!(transaction_id:, paid_at: Time.current)
    update!(status: "bezahlt", sumup_transaction_id: transaction_id, paid_at: paid_at)
    SupplementaryChargeMailer.receipt(self).deliver_later
  end

  # Hintergrund-Abgleich (via PaymentSyncJob): #success greift nur, wenn die
  # Eltern nach der Zahlung auf die Erfolgsseite zurückkehren UND SumUp dann
  # schon PAID meldet. Sonst blieb eine bezahlte Nachforderung für immer
  # "offen" (Fall Nilay Sümbül, 7 von 12 Q4-Rabattkorrekturen betroffen).
  def self.sync_open
    where(status: "offen").where.not(sumup_checkout_id: [ nil, "" ]).find_each do |charge|
      response = PaymentSyncService.fetch_checkout(charge.sumup_checkout_id)
      next unless response.is_a?(Net::HTTPSuccess)

      checkout = JSON.parse(response.body)
      next unless checkout["status"] == "PAID"

      txn = checkout.dig("transactions", 0) || {}
      charge.mark_paid!(transaction_id: txn["id"], paid_at: Time.zone.parse(txn["timestamp"].to_s) || Time.current)
      Rails.logger.info "[SupplementaryCharge.sync_open] Nachforderung #{charge.id} als bezahlt markiert"
    rescue => e
      Rails.logger.error "[SupplementaryCharge.sync_open] Fehler für Nachforderung #{charge.id}: #{e.class}: #{e.message}"
    end
  end
end
