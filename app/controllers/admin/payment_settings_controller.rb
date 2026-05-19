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
      unless ::SumupConfig.configured?
        return redirect_to admin_payment_setting_path,
                           alert: "Kein SumUp Access Token konfiguriert."
      end

      token = ::SumupConfig.valid_token
      unless token.present?
        return redirect_to admin_payment_setting_path,
                           alert: "Token konnte nicht ermittelt werden. Client-ID und Client-Secret prüfen."
      end

      uri = URI("https://api.sumup.com/v0.1/me/merchant-profile")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 10

      request = Net::HTTP::Get.new(uri.request_uri, {
        "Authorization" => "Bearer #{token}",
        "Accept"        => "application/json"
      })
      response = http.request(request)

      Rails.logger.info "[SumupConfig] test_connection response: #{response.code} #{response.body.truncate(200)}"

      case response.code.to_i
      when 200, 201
        redirect_to admin_payment_setting_path, notice: "Verbindung erfolgreich. SumUp API antwortet korrekt."
      when 401
        redirect_to admin_payment_setting_path,
                    alert: "Token ungültig (401). Bitte Access Token neu setzen oder Client-ID/Secret prüfen."
      when 403
        redirect_to admin_payment_setting_path,
                    alert: "Zugriff verweigert (403). Token-Scope unzureichend – bitte neuen Token via Client-Credentials holen."
      else
        redirect_to admin_payment_setting_path,
                    alert: "SumUp API antwortete mit Status #{response.code}: #{response.body.truncate(100)}"
      end
    rescue => e
      Rails.logger.error "[Admin::PaymentSettings] test_connection Fehler: #{e.class}: #{e.message}"
      redirect_to admin_payment_setting_path,
                  alert: "Verbindungsfehler: #{e.message}"
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
