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

  def self.client_id
    ENV["SUMUP_CLIENT_ID"]
  end

  def self.client_secret
    ENV["SUMUP_CLIENT_SECRET"]
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
    access_token.present? || (client_id.present? && client_secret.present?)
  end

  def self.fetch_token!
    unless client_id.present? && client_secret.present?
      Rails.logger.error "[SumupConfig] fetch_token! aufgerufen ohne SUMUP_CLIENT_ID/SUMUP_CLIENT_SECRET"
      return nil
    end

    uri = URI("https://api.sumup.com/token")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.path, { "Content-Type" => "application/x-www-form-urlencoded" })
    request.body = URI.encode_www_form(
      grant_type: "client_credentials",
      client_id: client_id,
      client_secret: client_secret
    )

    response = http.request(request)
    body = JSON.parse(response.body)
    token = body["access_token"]

    unless token.present?
      Rails.logger.error "[SumupConfig] fetch_token! kein access_token in Antwort: #{response.code} #{response.body}"
      return nil
    end

    s = setting || PaymentSetting.new
    s.sumup_access_token = token
    s.save!
    Rails.logger.info "[SumupConfig] Neuer Access Token via OAuth2 gespeichert."
    token
  rescue => e
    Rails.logger.error "[SumupConfig] fetch_token! Fehler: #{e.class}: #{e.message}"
    nil
  end

  def self.valid_token
    tok = access_token
    return tok if tok.present?
    fetch_token! if client_id.present? && client_secret.present?
  end
end
