Rails.application.config.after_initialize do
  Rails.logger.info "[SumupConfig] Access Token #{SumupConfig.configured? ? 'konfiguriert' : 'nicht gesetzt'}"
rescue => e
  Rails.logger.warn "[SumupConfig] Initializer error: #{e.message}"
end
