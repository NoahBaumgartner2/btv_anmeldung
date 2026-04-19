class PaymentSetting < ApplicationRecord
  CURRENCIES = %w[chf eur usd].freeze

  validates :currency, inclusion: { in: CURRENCIES }, allow_blank: true

  # ── Single-row accessor ─────────────────────────────────────────────────────
  def self.current
    first_or_initialize
  end

  # ── sumup_access_token (encrypted) ─────────────────────────────────────────
  def sumup_access_token=(value)
    @sumup_access_token = value
    self.sumup_access_token_encrypted = encryptor.encrypt_and_sign(value) if value.present?
  end

  def sumup_access_token
    return @sumup_access_token if @sumup_access_token
    return nil if sumup_access_token_encrypted.blank?
    encryptor.decrypt_and_verify(sumup_access_token_encrypted)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage,
         ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def sumup_access_token_present?
    sumup_access_token_encrypted.present?
  end

  # ── Convenience ────────────────────────────────────────────────────────────
  def fully_configured?
    sumup_api_key.present? && sumup_access_token_present?
  end

  def effective_currency
    currency.presence || "chf"
  end

  private

  def encryptor
    key = ActiveSupport::KeyGenerator
      .new(Rails.application.secret_key_base)
      .generate_key("payment_setting/sumup_secrets/v1", 32)
    ActiveSupport::MessageEncryptor.new(key)
  end
end
