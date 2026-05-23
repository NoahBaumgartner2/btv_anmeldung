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

  # Gibt einen gültigen Token zurück.
  def self.valid_token
    access_token
  end

  # Stellt sicher, dass der Token noch mindestens 5 Minuten gültig ist.
  # Sollte vor jedem SumUp-API-Aufruf aufgerufen werden.
  def self.ensure_valid_token!
    s = setting
    return unless s&.sumup_token_expires_at.present?
    return if s.sumup_token_expires_at > 5.minutes.from_now

    refresh_access_token!
  rescue => e
    Rails.logger.warn "[SumupConfig] Token-Refresh fehlgeschlagen: #{e.message}"
  end

  def self.refresh_access_token!
    s = setting
    return unless s&.sumup_client_id.present? && s.sumup_client_secret.present?

    uri = URI("https://api.sumup.com/token")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.path, { "Content-Type" => "application/x-www-form-urlencoded" })
    request.body = URI.encode_www_form(
      grant_type:    "client_credentials",
      client_id:     s.sumup_client_id,
      client_secret: s.sumup_client_secret
    )

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      raise "SumUp Token-Refresh HTTP #{response.code}: #{response.body}"
    end

    data = JSON.parse(response.body)
    new_token      = data["access_token"]
    expires_in_sec = data["expires_in"].to_i

    s.sumup_access_token    = new_token
    s.sumup_token_expires_at = Time.current + expires_in_sec.seconds
    s.save!

    Rails.logger.info "[SumupConfig] Access Token erneuert, gültig bis #{s.sumup_token_expires_at}"
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
