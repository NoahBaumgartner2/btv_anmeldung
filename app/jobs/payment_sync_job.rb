class PaymentSyncJob < ApplicationJob
  queue_as :default

  def perform
    unless SumupConfig.configured?
      Rails.logger.info "[PaymentSyncJob] SumUp nicht konfiguriert – übersprungen."
      return
    end

    Rails.logger.info "[PaymentSyncJob] Starte Zahlungs-Sync..."
    result = PaymentSyncService.sync_pending
    Rails.logger.info "[PaymentSyncJob] Sync abgeschlossen: " \
                      "#{result.total} geprüft, #{result.paid} bezahlt, " \
                      "#{result.still_pending} ausstehend, #{result.errors} Fehler."
  rescue => e
    Rails.logger.error "[PaymentSyncJob] #{e.class}: #{e.message}"
    raise
  end
end
