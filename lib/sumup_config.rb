require "net/http"
require "uri"
require "json"

module SumupConfig
  def self.setting
    PaymentSetting.first
  rescue => e
    Rails.logger.warn "[SumupConfig] DB read error: #{e.message}"
    nil
  end

  def self.access_token
    setting&.sumup_access_token.presence || ENV["SUMUP_ACCESS_TOKEN"].to_s
  end

  # Gibt einen gültigen Token zurück. Einstiegspunkt für zukünftigen OAuth2-Refresh.
  def self.valid_token
    access_token
  end

  def self.merchant_code
    setting&.sumup_merchant_code.presence || ENV["SUMUP_MERCHANT_CODE"].to_s
  end

  def self.currency
    setting&.effective_currency || ENV.fetch("SUMUP_CURRENCY", "chf")
  end

  def self.active?
    s = setting
    return ENV["SUMUP_ACCESS_TOKEN"].present? unless s&.persisted?
    s.active? && s.fully_configured?
  end

  def self.configured?
    access_token.present?
  end
end
