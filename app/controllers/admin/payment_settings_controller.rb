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
      Rails.logger.error "[Admin::PaymentSettings] sync_payments Fehler: #{e.message}"
      redirect_to admin_payment_setting_path, alert: "Fehler beim Abgleich: #{e.message}"
    end

    def test_connection
      unless ::SumupConfig.configured?
        return redirect_to admin_payment_setting_path,
                           alert: "Kein SumUp Access Token konfiguriert."
      end

      uri = URI("https://api.sumup.com/v0.1/me")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 10

      request = Net::HTTP::Get.new(uri.path, {
        "Authorization" => "Bearer #{::SumupConfig.access_token}"
      })

      response = http.request(request)

      case response.code.to_i
      when 200
        redirect_to admin_payment_setting_path,
                    notice: "Verbindung erfolgreich! SumUp API antwortet korrekt."
      when 401, 403
        redirect_to admin_payment_setting_path,
                    alert: "Authentifizierungsfehler: Der Access Token ist ungültig oder abgelaufen."
      else
        redirect_to admin_payment_setting_path,
                    alert: "SumUp API antwortete mit Status #{response.code}."
      end
    rescue => e
      redirect_to admin_payment_setting_path,
                  alert: "Verbindungsfehler: #{e.message}"
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
