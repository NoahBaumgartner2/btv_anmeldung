class ExpirePendingPaymentsJob < ApplicationJob
  queue_as :default

  def perform
    scope = CourseRegistration
      .where(status: "ausstehend", payment_cleared: false)
      .where("payment_expires_at < ?", Time.current)

    total     = scope.count
    cancelled = 0
    errors    = 0

    Rails.logger.info "[ExpirePendingPaymentsJob] #{total} abgelaufene Reservierung(en) gefunden."

    scope.includes(:course, participant: :user).find_each do |registration|
      did_cancel = false

      # with_lock re-loads the row with an exclusive lock inside a transaction,
      # preventing a concurrent PaymentSyncJob from clearing the payment between
      # our query and the status update.
      registration.with_lock do
        next if registration.status != "ausstehend" || registration.payment_cleared?

        registration.update!(status: "storniert")

        # promote_from_waitlist wurde zu WaitlistPromotionService extrahiert –
        # daher explizit aufrufen.
        WaitlistPromotionService.promote_next_from_waitlist(
          registration.course,
          training_session_id: registration.training_session_id
        )

        did_cancel = true
      end

      next unless did_cancel

      # Mailer nach der Transaktion versenden, damit er nur bei erfolgreichem
      # Commit ausgeführt wird.
      CourseRegistrationMailer.payment_expired(registration).deliver_later

      Rails.logger.info "[ExpirePendingPaymentsJob] Registration #{registration.id} storniert " \
                        "(#{registration.participant.first_name} #{registration.participant.last_name}, " \
                        "Kurs: #{registration.course.title})."
      cancelled += 1
    rescue => e
      errors += 1
      Rails.logger.error "[ExpirePendingPaymentsJob] Fehler bei Registration #{registration.id}: " \
                         "#{e.class}: #{e.message}"
    end

    Rails.logger.info "[ExpirePendingPaymentsJob] Abgeschlossen: #{total} geprüft, " \
                      "#{cancelled} storniert, #{errors} Fehler."
  end
end
