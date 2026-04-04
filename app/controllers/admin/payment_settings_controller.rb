module Admin
  class PaymentSettingsController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!

    def show
      @payment_setting = PaymentSetting.current
    end

    def edit
      @payment_setting = PaymentSetting.current
    end

    def update
      @payment_setting = PaymentSetting.current

      if @payment_setting.update(payment_setting_params)
        ::Stripe.api_key = ::StripeConfig.secret_key
        redirect_to admin_payment_setting_path, notice: "Zahlungseinstellungen wurden gespeichert."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def test_connection
      @payment_setting = PaymentSetting.current

      unless ::StripeConfig.configured?
        return redirect_to admin_payment_setting_path,
                           alert: "Kein Stripe Secret Key konfiguriert."
      end

      ::Stripe.api_key = ::StripeConfig.secret_key
      Stripe::Balance.retrieve
      redirect_to admin_payment_setting_path,
                  notice: "Verbindung erfolgreich! Stripe API antwortet korrekt."
    rescue Stripe::AuthenticationError
      redirect_to admin_payment_setting_path,
                  alert: "Authentifizierungsfehler: Der Secret Key ist ungültig."
    rescue Stripe::StripeError => e
      redirect_to admin_payment_setting_path,
                  alert: "Stripe-Fehler: #{e.message}"
    rescue => e
      redirect_to admin_payment_setting_path,
                  alert: "Verbindungsfehler: #{e.message}"
    end

    private

    def payment_setting_params
      params.require(:payment_setting).permit(
        :stripe_publishable_key, :stripe_secret_key, :stripe_webhook_secret,
        :currency, :active
      )
    end
  end
end
