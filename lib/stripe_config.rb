module StripeConfig
  def self.setting
    PaymentSetting.first
  rescue => e
    Rails.logger.warn "[StripeConfig] DB read error: #{e.message}"
    nil
  end

  def self.secret_key
    setting&.stripe_secret_key.presence || ENV["STRIPE_SECRET_KEY"].to_s
  end

  def self.webhook_secret
    setting&.stripe_webhook_secret.presence || ENV["STRIPE_WEBHOOK_SECRET"].to_s
  end

  def self.publishable_key
    setting&.stripe_publishable_key.presence || ENV["STRIPE_PUBLISHABLE_KEY"].to_s
  end

  def self.currency
    setting&.effective_currency || ENV.fetch("STRIPE_CURRENCY", "chf")
  end

  def self.active?
    s = setting
    return ENV["STRIPE_SECRET_KEY"].present? unless s&.persisted?
    s.active? && s.fully_configured?
  end

  def self.configured?
    secret_key.present?
  end
end
