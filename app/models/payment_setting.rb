class PaymentSetting < ApplicationRecord
  CURRENCIES = %w[chf eur usd].freeze

  validates :currency, inclusion: { in: CURRENCIES }, allow_blank: true

  # ── Single-row accessor ─────────────────────────────────────────────────────
  def self.current
    first_or_initialize
  end

  # ── stripe_secret_key (encrypted) ──────────────────────────────────────────
  attr_reader :stripe_secret_key

  def stripe_secret_key=(value)
    @stripe_secret_key = value
    self.stripe_secret_key_encrypted = encryptor.encrypt_and_sign(value) if value.present?
  end

  def stripe_secret_key
    return @stripe_secret_key if @stripe_secret_key
    return nil if stripe_secret_key_encrypted.blank?
    encryptor.decrypt_and_verify(stripe_secret_key_encrypted)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage,
         ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def stripe_secret_key_present?
    stripe_secret_key_encrypted.present?
  end

  # ── stripe_webhook_secret (encrypted) ──────────────────────────────────────
  attr_reader :stripe_webhook_secret

  def stripe_webhook_secret=(value)
    @stripe_webhook_secret = value
    self.stripe_webhook_secret_encrypted = encryptor.encrypt_and_sign(value) if value.present?
  end

  def stripe_webhook_secret
    return @stripe_webhook_secret if @stripe_webhook_secret
    return nil if stripe_webhook_secret_encrypted.blank?
    encryptor.decrypt_and_verify(stripe_webhook_secret_encrypted)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage,
         ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def stripe_webhook_secret_present?
    stripe_webhook_secret_encrypted.present?
  end

  # ── Convenience ────────────────────────────────────────────────────────────
  def fully_configured?
    stripe_publishable_key.present? && stripe_secret_key_present?
  end

  def effective_currency
    currency.presence || "chf"
  end

  private

  def encryptor
    key = ActiveSupport::KeyGenerator
      .new(Rails.application.secret_key_base)
      .generate_key("payment_setting/stripe_secrets/v1", 32)
    ActiveSupport::MessageEncryptor.new(key)
  end
end
