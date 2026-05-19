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
        redirect_to admin_payment_setting_path, notice: "Zahlungseinstellungen wurden gespeichert."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def sync_payments
      unless ::SumupConfig.configured?
        return redirect_to admin_payment_setting_path,
                           alert: "Kein SumUp Access Token konfiguriert."
      end

      result = PaymentSyncService.sync_pending

      if result.errors > 0
        msg = "Abgleich abgeschlossen: #{result.paid} bezahlt, #{result.still_pending} ausstehend, #{result.errors} Fehler (Details im Log)."
        redirect_to admin_payment_setting_path, alert: msg
      else
        msg = "Abgleich abgeschlossen: #{result.total} geprüft, #{result.paid} als bezahlt markiert, #{result.still_pending} noch ausstehend."
        redirect_to admin_payment_setting_path, notice: msg
      end
    rescue => e
      Rails.logger.error "[Admin::PaymentSettings] sync_payments Fehler: #{e.class}: #{e.message}"
      redirect_to admin_payment_setting_path, alert: "Der Zahlungsabgleich konnte nicht durchgeführt werden. Bitte versuche es erneut."
    end

    def test_connection
      # Fall 1: Client-ID + Secret vorhanden → Token-Fetch als Verbindungstest
      if ::SumupConfig.client_id.present? && ::SumupConfig.client_secret.present?
        new_token = ::SumupConfig.fetch_token!
        if new_token.present?
          redirect_to admin_payment_setting_path,
                      notice: "Verbindung erfolgreich. Neuer Access Token wurde von SumUp ausgestellt und gespeichert."
        else
          redirect_to admin_payment_setting_path,
                      alert: "Verbindung fehlgeschlagen. Client-ID oder Client-Secret ungültig – kein Token erhalten."
        end
        return
      end

      # Fall 2: Nur manueller Access Token (kein Client-Secret) → nur prüfen ob vorhanden
      if ::SumupConfig.access_token.present?
        redirect_to admin_payment_setting_path,
                    notice: "Access Token ist gesetzt. Ohne Client-ID/Secret kann die Verbindung nicht automatisch getestet werden."
      else
        redirect_to admin_payment_setting_path,
                    alert: "Kein SumUp Access Token und keine Client-Credentials konfiguriert."
      end
    end

    private

    def payment_setting_params
      params.require(:payment_setting).permit(
        :sumup_api_key, :sumup_access_token, :sumup_merchant_code,
        :sumup_client_id, :sumup_client_secret,
        :currency, :active
      )
    end
  end
end
