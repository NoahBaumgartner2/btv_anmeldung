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
end
