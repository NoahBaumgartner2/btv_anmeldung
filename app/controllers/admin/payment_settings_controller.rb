module Admin
  class PaymentSettingsController < ApplicationController
    include SettingsLoadable

    before_action :authenticate_user!
    before_action :authorize_admin!

    # Zahlungseinstellungen leben jetzt im Zahlungen-Tab des Einstellungs-Hubs.
    def show
      redirect_to admin_settings_payments_path
    end

    def edit
      redirect_to admin_settings_payments_path
    end

    def update
      @payment_setting = PaymentSetting.current

      if @payment_setting.update(payment_setting_params)
        redirect_to admin_settings_payments_path, notice: "Zahlungseinstellungen wurden gespeichert."
      else
        load_payment_settings
        render "admin/settings/payments", status: :unprocessable_entity
      end
    end

    def sync_payments
      unless ::SumupConfig.configured?
        return redirect_to admin_settings_payments_path,
                           alert: "Kein SumUp Access Token konfiguriert."
      end

      result = PaymentSyncService.sync_pending

      if result.errors > 0
        msg = "Abgleich abgeschlossen: #{result.paid} bezahlt, #{result.still_pending} ausstehend, #{result.errors} Fehler (Details im Log)."
        redirect_to admin_settings_payments_path, alert: msg
      else
        msg = "Abgleich abgeschlossen: #{result.total} geprüft, #{result.paid} als bezahlt markiert, #{result.still_pending} noch ausstehend."
        redirect_to admin_settings_payments_path, notice: msg
      end
    rescue => e
      Rails.logger.error "[Admin::PaymentSettings] sync_payments Fehler: #{e.class}: #{e.message}"
      redirect_to admin_settings_payments_path, alert: "Der Zahlungsabgleich konnte nicht durchgeführt werden. Bitte versuche es erneut."
    end

    def test_connection
      unless ::SumupConfig.configured?
        return redirect_to admin_settings_payments_path,
                           alert: "Kein API Key konfiguriert."
      end

      redirect_to admin_settings_payments_path,
                  notice: "API Key ist gesetzt und bereit. Die Verbindung wird beim nächsten Checkout automatisch getestet."
    end

    private

    def payment_setting_params
      params.require(:payment_setting).permit(
        :sumup_api_key, :sumup_access_token, :sumup_merchant_code,
        :currency, :active
      )
    end
  end
end
