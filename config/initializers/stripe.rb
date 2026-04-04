Rails.application.config.after_initialize do
  Stripe.api_key = StripeConfig.secret_key
rescue => e
  Rails.logger.warn "[Stripe] Initializer error: #{e.message}"
end
