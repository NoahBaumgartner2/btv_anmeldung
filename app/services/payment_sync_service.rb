# Kapselt die Logik zum Abgleichen ausstehender Zahlungen mit Stripe.
# Genutzt von:
#   - Admin::PaymentSettingsController#sync_payments (Admin-UI)
#   - StripeWebhooksController (Webhook-Events)
#   - rake payments:sync_pending (Cronjob)
class PaymentSyncService
  Result = Struct.new(:total, :paid, :still_pending, :errors, keyword_init: true)

  # Markiert eine einzelne Registration als bezahlt und setzt den korrekten Status.
  # Wird direkt vom Webhook aufgerufen.
  def self.mark_paid!(registration, payment_intent: nil, session_id: nil)
    course = registration.course
    confirmed_count = course.course_registrations.where(status: "bestätigt").count
    new_status = if course.max_participants.present? && confirmed_count >= course.max_participants
                   "warteliste"
                 else
                   "bestätigt"
                 end

    registration.update!(
      payment_cleared:          true,
      stripe_payment_intent_id: payment_intent,
      stripe_session_id:        session_id || registration.stripe_session_id,
      status:                   new_status
    )
  end

  # Holt alle ausstehenden Registrierungen mit Stripe-Session und prüft den
  # Zahlungsstatus direkt bei Stripe. Gibt ein Result-Struct zurück.
  def self.sync_pending
    ::Stripe.api_key = ::StripeConfig.secret_key

    pending = CourseRegistration.where(
      status:          "ausstehend",
      payment_cleared: false
    ).where.not(stripe_session_id: [nil, ""])

    total        = pending.size
    paid_count   = 0
    error_count  = 0

    pending.each do |registration|
      stripe_session = ::Stripe::Checkout::Session.retrieve(registration.stripe_session_id)

      if stripe_session.payment_status == "paid"
        mark_paid!(registration,
                   payment_intent: stripe_session.payment_intent,
                   session_id:     stripe_session.id)
        paid_count += 1
        Rails.logger.info "[PaymentSyncService] Registration #{registration.id} als bezahlt markiert"
      else
        Rails.logger.info "[PaymentSyncService] Registration #{registration.id} noch ausstehend (#{stripe_session.payment_status})"
      end
    rescue ::Stripe::StripeError => e
      error_count += 1
      Rails.logger.error "[PaymentSyncService] Stripe-Fehler für Registration #{registration.id}: #{e.message}"
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
end
