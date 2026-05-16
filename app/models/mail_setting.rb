class MailSetting < ApplicationRecord
  AUTHENTICATION_OPTIONS = %w[plain login cram_md5].freeze

  HOSTNAME_REGEXP = /\A[a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?)*\z/i

  validates :smtp_port, numericality: { only_integer: true, greater_than: 0, less_than: 65_536 }, allow_blank: true
  validates :smtp_authentication, inclusion: { in: AUTHENTICATION_OPTIONS }, allow_blank: true
  validates :app_host, format: { with: HOSTNAME_REGEXP, message: "muss ein gültiger Hostname sein (z.B. btvbern-anmeldung.ch)" }, allow_blank: true

  # ── Virtual attribute for password (stored encrypted) ──────────────────────
  attr_reader :smtp_password

  def smtp_password=(plaintext)
    @smtp_password = plaintext
    # Leer lassen → bestehendes Passwort beibehalten
    self.smtp_password_encrypted = encryptor.encrypt_and_sign(plaintext) if plaintext.present?
  end

  def smtp_password_decrypted
    return nil if smtp_password_encrypted.blank?
    encryptor.decrypt_and_verify(smtp_password_encrypted)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  # ── Single-row accessor ─────────────────────────────────────────────────────
  def self.current
    first_or_initialize
  end

  # Opens a raw SMTP connection (TCP + optional STARTTLS + auth) without sending
  # a message — useful as a pre-flight connectivity check from the admin UI.
  def self.test_connection
    setting = first
    return { success: false, error: "Keine SMTP-Einstellungen konfiguriert." } unless setting&.smtp_host.present?

    require "net/smtp"
    smtp     = Net::SMTP.new(setting.smtp_host, (setting.smtp_port.presence || 587).to_i)
    smtp.enable_starttls_auto if setting.smtp_enable_starttls

    user     = setting.smtp_username.presence
    password = setting.smtp_password_decrypted
    authtype = setting.smtp_authentication.presence&.to_sym

    smtp.start("localhost", user, password, authtype) { }

    { success: true }
  rescue Net::SMTPAuthenticationError => e
    { success: false, error: "Authentifizierungsfehler: #{e.message.to_s.truncate(200)}" }
  rescue => e
    { success: false, error: "#{e.class}: #{e.message.to_s.truncate(200)}" }
  end

  # ── Apply SMTP settings to ActionMailer ────────────────────────────────────
  def self.apply!
    setting = first

    if setting&.smtp_host.present?
      ActionMailer::Base.delivery_method = :smtp
      ActionMailer::Base.smtp_settings   = setting.to_smtp_hash
      ActionMailer::Base.default(from: setting.from_header) if setting.from_header.present?
    else
      apply_from_env!
    end

    from = ActionMailer::Base.default_params[:from]
    Devise.mailer_sender = from if from.present?

    # config/environments/production.rb setzt default_url_options aus ENV während der
    # Config-Phase. Dieser Block läuft in after_initialize – nach den Railtie-Initializers –
    # und überschreibt den ENV-Wert bewusst, damit der DB-Wert immer Vorrang hat.
    if setting&.app_host.present? && setting.app_host.match?(HOSTNAME_REGEXP)
      ActionMailer::Base.default_url_options = { host: setting.app_host, protocol: "https" }
    end
  rescue => e
    Rails.logger.warn "[MailSetting] Could not apply DB settings: #{e.message}. Falling back to ENV."
    apply_from_env!
  end

  def self.apply_from_env!
    return unless ENV["SMTP_HOST"].present?

    ActionMailer::Base.delivery_method = :smtp
    ActionMailer::Base.smtp_settings = {
      address:              ENV["SMTP_HOST"],
      port:                 ENV.fetch("SMTP_PORT", 587).to_i,
      user_name:            ENV["SMTP_USERNAME"],
      password:             ENV["SMTP_PASSWORD"],
      authentication:       (ENV.fetch("SMTP_AUTHENTICATION", "plain")).to_sym,
      enable_starttls_auto: ENV.fetch("SMTP_ENABLE_STARTTLS", "true") == "true"
    }.compact

    from = [ENV["SMTP_FROM_NAME"], ENV["SMTP_FROM_ADDRESS"]].compact.join(" ")
    ActionMailer::Base.default(from: from) if from.present?
  end

  def to_smtp_hash
    {
      address:              smtp_host,
      port:                 smtp_port || 587,
      user_name:            smtp_username.presence,
      password:             smtp_password_decrypted,
      authentication:       smtp_authentication.presence&.to_sym,
      enable_starttls_auto: smtp_enable_starttls
    }.compact
  end

  def from_header
    if smtp_from_name.present? && smtp_from_address.present?
      "#{smtp_from_name} <#{smtp_from_address}>"
    elsif smtp_from_address.present?
      smtp_from_address
    end
  end

  private

  def encryptor
    key = ActiveSupport::KeyGenerator
      .new(Rails.application.secret_key_base)
      .generate_key("mail_setting/smtp_password/v1", 32)
    ActiveSupport::MessageEncryptor.new(key)
  end
end
