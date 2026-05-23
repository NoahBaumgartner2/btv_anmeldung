namespace :payments do
  desc "Gleicht ausstehende SumUp-Zahlungen ab (für Cronjob-Nutzung)"
  task sync_pending: :environment do
    unless SumupConfig.configured?
      puts "SumUp nicht konfiguriert – Abgleich übersprungen."
      next
    end

    puts "Starte Zahlungsabgleich..."
    result = PaymentSyncService.sync_pending

    puts "Abgeschlossen:"
    puts "  Geprüft:       #{result.total}"
    puts "  Als bezahlt:   #{result.paid}"
    puts "  Noch offen:    #{result.still_pending}"
    puts "  Fehler:        #{result.errors}"
  end

  desc "Storniert ausstehende Zahlungen deren Frist abgelaufen ist"
  task expire_pending: :environment do
    expired = CourseRegistration
      .where(status: "ausstehend", payment_cleared: false)
      .where("payment_expires_at < ?", Time.current)

    total     = expired.count
    cancelled = 0
    errors    = 0

    puts "#{total} abgelaufene Reservierung(en) gefunden."

    expired.find_each do |registration|
      did_cancel = false

      registration.with_lock do
        next if registration.status != "ausstehend" || registration.payment_cleared?

        registration.update!(status: "storniert")
        WaitlistPromotionService.promote_next_from_waitlist(
          registration.course,
          training_session_id: registration.training_session_id
        )
        did_cancel = true
      end

      next unless did_cancel

      CourseRegistrationMailer.payment_expired(registration).deliver_later
      puts "  Storniert: Registration #{registration.id} " \
           "(#{registration.participant.first_name} #{registration.participant.last_name}, " \
           "Kurs: #{registration.course.title})"
      cancelled += 1
    rescue => e
      errors += 1
      puts "  FEHLER bei Registration #{registration.id}: #{e.class}: #{e.message}"
    end

    puts "Abgeschlossen: #{total} geprüft, #{cancelled} storniert, #{errors} Fehler."
  end
end
