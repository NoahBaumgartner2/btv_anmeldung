# Infomaniak Newsletter API – Konfiguration
#
# Credentials werden aus Rails Credentials gelesen (Key: `infomaniak`).
# Eintragen via: bin/rails credentials:edit
# Beispielstruktur: config/credentials/infomaniak.yml.example

module InfomaniakConfig
  REQUIRED_KEYS = %i[api_token mailing_list_id base_url].freeze

  # Schützt @config vor Race Conditions unter Puma (multi-threaded).
  CONFIG_LOCK = Mutex.new
  private_constant :CONFIG_LOCK

  class << self
    # Thread-sicherer Lesezugriff auf die aktuelle Konfiguration.
    def config
      CONFIG_LOCK.synchronize { @config }
    end

    def configured?
      c = config
      c&.api_token.present? && c&.mailing_list_id.present?
    end

    # Liest Konfiguration aus DB (Vorrang) und fällt auf Credentials zurück.
    # Thread-sicher: @config wird atomar ersetzt.
    def load!
      raw        = Rails.application.credentials.infomaniak
      db_setting = load_from_db

      new_config = ActiveSupport::OrderedOptions.new.tap do |cfg|
        cfg.api_token       = db_setting&.api_token.presence       || raw&.dig(:api_token)
        cfg.mailing_list_id = db_setting&.mailing_list_id.presence || raw&.dig(:mailing_list_id)
        cfg.base_url        = db_setting&.effective_base_url        || raw&.dig(:base_url).presence || "https://api.infomaniak.com"
      end

      CONFIG_LOCK.synchronize do
        @config = new_config
        # Mirror auf Rails.application.config für ServiceObject-Zugriff
        Rails.application.config.infomaniak = @config
      end
    end

    def reload!
      load!
    end

    private

    def load_from_db
      ::InfomaniakSetting.first
    rescue => e
      Rails.logger.warn "[InfomaniakConfig] DB-Lese-Fehler: #{e.message}"
      nil
    end
  end
end

# Beim Asset-Precompile-Schritt im Docker-Build ist keine DB verfügbar.
# In diesem Fall überspringen wir das Laden der DB-Konfiguration.
if ENV["SECRET_KEY_BASE_DUMMY"].present?
  Rails.logger.info "[InfomaniakConfig] Asset-Precompile-Modus – DB-Konfiguration wird übersprungen."
else
  Rails.application.config.after_initialize do
    next unless defined?(InfomaniakSetting) &&
                ActiveRecord::Base.connection.table_exists?("infomaniak_settings")

    begin
      InfomaniakConfig.load!
      Rails.logger.info "[InfomaniakConfig] Konfiguration geladen – " \
                        "#{InfomaniakConfig.configured? ? 'vollständig' : 'unvollständig (Dev/Test)'}"
    rescue => e
      if Rails.env.production?
        raise e
      else
        Rails.logger.warn "[InfomaniakConfig] Initializer übersprungen: #{e.message}"
      end
    end
  end
end
