class InfomaniakSetting < ApplicationRecord
  ALLOWED_BASE_URL = "https://api.infomaniak.com"

  validates :base_url,
            inclusion: {
              in: [ nil, "", ALLOWED_BASE_URL ],
              message: "muss leer oder exakt \"#{ALLOWED_BASE_URL}\" sein"
            }

  # ── Single-row accessor ─────────────────────────────────────────────────────
  def self.current
    first_or_initialize
  end

  # ── api_token (encrypted) ───────────────────────────────────────────────────
  def api_token=(value)
    @api_token = value
    self.api_token_encrypted = encryptor.encrypt_and_sign(value) if value.present?
  end

  def api_token
    return @api_token if @api_token
    return nil if api_token_encrypted.blank?

    encryptor.decrypt_and_verify(api_token_encrypted)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage,
         ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def api_token_present?
    api_token_encrypted.present?
  end

  # ── Convenience ─────────────────────────────────────────────────────────────
  def configured?
    api_token_present? && mailing_list_id.present?
  end

  def effective_base_url
    base_url.presence || "https://api.infomaniak.com"
  end

  private

  def encryptor
    key = ActiveSupport::KeyGenerator
      .new(Rails.application.secret_key_base)
      .generate_key("infomaniak_setting/api_token/v1", 32)
    ActiveSupport::MessageEncryptor.new(key)
  end
end
