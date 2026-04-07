Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data, :https
    policy.object_src  :none

    # Scripts: self + Stripe JS
    # Nonce für Inline-Scripts wird automatisch via content_security_policy_nonce_directives ergänzt
    policy.script_src :self, "https://js.stripe.com"

    # Styles: self
    # Nonce für Inline-Styles wird automatisch via content_security_policy_nonce_directives ergänzt
    policy.style_src :self

    # Stripe Checkout/Payment-Frames
    policy.frame_src "https://js.stripe.com", "https://hooks.stripe.com"

    # Stripe API-Calls aus dem Browser
    policy.connect_src :self, "https://api.stripe.com"
  end

  # Nonce-Generator: sichere zufällige Nonce pro Request
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }

  # Nonce für script-src und style-src erzwingen
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
