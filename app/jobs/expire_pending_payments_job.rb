class ExpirePendingPaymentsJob < ApplicationJob
  queue_as :default

  def perform
    # "platz_frei" = frei gewordener Wartelistenplatz mit offener Entscheidung
    # (Schnuppern/Anmelden). Verfällt die 7-Tage-Frist, wird der Platz freigegeben.
    expirable_statuses = [ "ausstehend", "platz_frei" ]

    scope = CourseRegistration
      .where(status: expirable_statuses, payment_cleared: false)
      .where("payment_expires_at < ?", Time.current)

    total     = scope.count
    cancelled = 0
    errors    = 0

    Rails.logger.info "[ExpirePendingPaymentsJob] #{total} abgelaufene Reservierung(en) gefunden."

    stuck = CourseRegistration.where(status: expirable_statuses, payment_cleared: false)
                               .where(payment_expires_at: nil).count
    if stuck > 0
      Rails.logger.warn "[ExpirePendingPaymentsJob] WARNUNG: #{stuck} ausstehende Registrierung(en) ohne payment_expires_at gefunden – diese werden nie automatisch storniert!"
    end

    scope.includes(:course, participant: :user).find_each do |registration|
      did_cancel = false
      was_spot_offer = false

      # with_lock re-loads the row with an exclusive lock inside a transaction,
      # preventing a concurrent PaymentSyncJob from clearing the payment between
      # our query and the status update.
      registration.with_lock do
        next if expirable_statuses.exclude?(registration.status) || registration.payment_cleared?

        was_spot_offer = registration.status == "platz_frei"
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

      # Mail versenden bei: abgelaufenem Platzangebot ("platz_frei") ODER wenn die Anmeldung
      # aus einem Schnupperplatz stammt (trial_expires_at gesetzt, zugesicherte Frist).
      # Reguläre, still verfallene Reservierungen (ausstehend ohne Schnupperhintergrund)
      # werden ohne Mail storniert. Mailer nach der Transaktion versenden.
      if was_spot_offer || registration.trial_expires_at.present?
        CourseRegistrationMailer.payment_expired(registration, was_spot_offer: was_spot_offer).deliver_later
      else
        Rails.logger.info "[ExpirePendingPaymentsJob] Registration #{registration.id} regulär – " \
                          "still storniert ohne Mail."
      end

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
