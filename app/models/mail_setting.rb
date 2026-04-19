class MailSetting < ApplicationRecord
  AUTHENTICATION_OPTIONS = %w[plain login cram_md5].freeze

  validates :smtp_port, numericality: { only_integer: true, greater_than: 0, less_than: 65_536 }, allow_blank: true
  validates :smtp_authentication, inclusion: { in: AUTHENTICATION_OPTIONS }, allow_blank: true

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

  # ── Apply SMTP settings to ActionMailer ────────────────────────────────────
  def self.apply!
    setting = first

    if setting&.smtp_host.present?
      ActionMailer::Base.delivery_method  = :smtp
      ActionMailer::Base.smtp_settings    = setting.to_smtp_hash
      ActionMailer::Base.default_options  = { from: setting.from_header }
    else
      apply_from_env!
    end

    from = ActionMailer::Base.default_options[:from]
    Devise.mailer_sender = from if from.present?
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
    ActionMailer::Base.default_options = { from: from } if from.present?
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
