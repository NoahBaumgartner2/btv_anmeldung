require "timeout"

# Kapselt die Logik zum Abgleichen ausstehender Zahlungen mit SumUp.
# Genutzt von:
#   - Admin::PaymentSettingsController#sync_payments (Admin-UI)
#   - SumupWebhooksController (Webhook-Events)
#   - rake payments:sync_pending (Cronjob)
class PaymentSyncService
  Result = Struct.new(:total, :paid, :still_pending, :errors, keyword_init: true)

  # Markiert eine einzelne Registration als bezahlt und setzt den korrekten Status.
  # Wird direkt vom Webhook aufgerufen. Pessimistischer Lock verhindert Race Conditions
  # bei gleichzeitigen Webhook- und Success-Callback-Aufrufen.
  def self.mark_paid!(registration, transaction_id: nil, checkout_id: nil)
    registration.course.with_lock do
      registration.reload
      return if registration.payment_cleared?

      course = registration.course
      confirmed_count = course.course_registrations.where(status: "bestätigt").count
      new_status = if course.max_participants.present? && confirmed_count >= course.max_participants
                     "warteliste"
                   else
                     "bestätigt"
                   end

      registration.update!(
        payment_cleared:      true,
        sumup_transaction_id: transaction_id,
        sumup_checkout_id:    checkout_id || registration.sumup_checkout_id,
        status:               new_status
      )
    end
  end

  # Holt alle ausstehenden Registrierungen mit SumUp-Checkout-ID und prüft den
  # Zahlungsstatus direkt bei SumUp. Gibt ein Result-Struct zurück.
  def self.sync_pending
    pending = CourseRegistration.where(
      status:          "ausstehend",
      payment_cleared: false
    ).where.not(sumup_checkout_id: [nil, ""])

    total       = pending.size
    paid_count  = 0
    error_count = 0

    pending.each do |registration|
      response = fetch_checkout(registration.sumup_checkout_id)

      unless response.is_a?(Net::HTTPSuccess)
        error_count += 1
        Rails.logger.error "[PaymentSyncService] SumUp API-Fehler #{response.code} für Registration #{registration.id}"
        next
      end

      checkout = JSON.parse(response.body)

      if checkout["status"] == "PAID"
        transaction_id = checkout.dig("transactions", 0, "id")
        mark_paid!(registration,
                   transaction_id: transaction_id,
                   checkout_id:    checkout["id"])
        paid_count += 1
        Rails.logger.info "[PaymentSyncService] Registration #{registration.id} als bezahlt markiert"
      else
        Rails.logger.info "[PaymentSyncService] Registration #{registration.id} noch ausstehend (#{checkout['status']})"
      end
    rescue => e
      error_count += 1
      Rails.logger.error "[PaymentSyncService] Unerwarteter Fehler für Registration #{registration.id}: #{e.class}: #{e.message}"
    end

    Result.new(
      total:         total,
      paid:          paid_count,
      still_pending: total - paid_count - error_count,
      errors:        error_count
    )
  end

  def self.fetch_checkout(checkout_id)
    uri = URI("https://api.sumup.com/v0.1/checkouts/#{checkout_id}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.path, {
      "Authorization" => "Bearer #{::SumupConfig.access_token}"
    })

    http.request(request)
  rescue SocketError, Timeout::Error, Errno::ECONNREFUSED,
         Net::OpenTimeout, Net::ReadTimeout => e
    raise RuntimeError, "SumUp API nicht erreichbar: #{e.message}"
  end
end
