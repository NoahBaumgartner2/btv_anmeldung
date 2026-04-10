# Infomaniak Newsletter API – Konfiguration
#
# Credentials werden aus Rails Credentials gelesen (Key: `infomaniak`).
# Eintragen via: bin/rails credentials:edit
# Beispielstruktur: config/credentials/infomaniak.yml.example

module InfmaniakConfig
  REQUIRED_KEYS = %i[api_token mailing_list_id base_url].freeze

  class << self
    def load!
      raw = Rails.application.credentials.infomaniak

      if Rails.env.production?
        missing = REQUIRED_KEYS.select { |k| raw&.dig(k).blank? }
        if missing.any?
          raise <<~MSG
            [InfomaniakConfig] Fehlende Credentials in Production: #{missing.join(', ')}.
            Bitte via `bin/rails credentials:edit` unter dem Key `infomaniak` eintragen.
            Beispielstruktur: config/credentials/infomaniak.yml.example
          MSG
        end
      end

      Rails.application.config.infomaniak = ActiveSupport::OrderedOptions.new.tap do |cfg|
        cfg.api_token       = raw&.dig(:api_token)
        cfg.mailing_list_id = raw&.dig(:mailing_list_id)
        cfg.base_url        = raw&.dig(:base_url).presence || "https://api.infomaniak.com"
      end
    end

    def configured?
      cfg = Rails.application.config.infomaniak
      cfg&.api_token.present? && cfg&.mailing_list_id.present?
    rescue NameError
      false
    end
  end
end

begin
  InfmaniakConfig.load!
  Rails.logger.info "[InfomaniakConfig] Konfiguration geladen – " \
                    "#{InfmaniakConfig.configured? ? 'vollständig' : 'unvollständig (Dev/Test)'}"
rescue RuntimeError => e
  raise e  # In Production immer hart fehlschlagen
rescue => e
  Rails.logger.warn "[InfomaniakConfig] Initializer übersprungen: #{e.message}"
end
