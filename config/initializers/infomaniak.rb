# Infomaniak Newsletter API – Konfiguration
#
# Credentials werden aus Rails Credentials gelesen (Key: `infomaniak`).
# Eintragen via: bin/rails credentials:edit
# Beispielstruktur: config/credentials/infomaniak.yml.example

module InfomaniakConfig
  REQUIRED_KEYS = %i[api_token mailing_list_id base_url].freeze

  # Config wird direkt im Modul gehalten (attr_reader), damit `configured?`
  # nie auf `Rails.application.config` zugreifen muss – dessen method_missing
  # ruft `super` und wirft NoMethodError, wenn der Key nie gesetzt wurde.
  class << self
    attr_reader :config

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

      @config = ActiveSupport::OrderedOptions.new.tap do |cfg|
        cfg.api_token       = raw&.dig(:api_token)
        cfg.mailing_list_id = raw&.dig(:mailing_list_id)
        cfg.base_url        = raw&.dig(:base_url).presence || "https://api.infomaniak.com"
      end

      # Mirror auf Rails.application.config für ServiceObject-Zugriff
      Rails.application.config.infomaniak = @config
    end

    def configured?
      config&.api_token.present? && config&.mailing_list_id.present?
    end
  end
end

begin
  InfomaniakConfig.load!
  Rails.logger.info "[InfomaniakConfig] Konfiguration geladen – " \
                    "#{InfomaniakConfig.configured? ? 'vollständig' : 'unvollständig (Dev/Test)'}"
rescue RuntimeError => e
  raise e  # In Production immer hart fehlschlagen
rescue => e
  Rails.logger.warn "[InfomaniakConfig] Initializer übersprungen: #{e.message}"
end
