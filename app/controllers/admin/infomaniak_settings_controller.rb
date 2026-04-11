module Admin
  class InfomaniakSettingsController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!

    def show
      @infomaniak_setting = InfomaniakSetting.current
    end

    def edit
      @infomaniak_setting = InfomaniakSetting.current
    end

    def update
      @infomaniak_setting = InfomaniakSetting.current

      if @infomaniak_setting.update(infomaniak_setting_params)
        InfomaniakConfig.reload!
        redirect_to admin_infomaniak_setting_path, notice: "Infomaniak-Einstellungen wurden gespeichert."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def test_connection
      unless InfomaniakConfig.configured?
        return redirect_to admin_infomaniak_setting_path,
                           alert: "Kein API-Token konfiguriert."
      end

      # Hardcodierter Endpunkt – die konfigurierbare base_url wird bewusst
      # nicht verwendet, um Token-Exfiltration an fremde Server zu verhindern.
      # Dieser Test prüft ausschliesslich ob der Token bei Infomaniak gültig ist.
      uri               = URI("https://api.infomaniak.com/1/profile")
      http              = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.read_timeout = 10
      http.open_timeout = 5

      request = Net::HTTP::Get.new(uri.request_uri, {
        "Authorization" => "Bearer #{InfomaniakConfig.config.api_token}",
        "Accept"        => "application/json"
      })

      response = http.request(request)

      case response.code.to_i
      when 200
        redirect_to admin_infomaniak_setting_path,
                    notice: "Verbindung erfolgreich! Infomaniak API antwortet korrekt."
      when 401, 403
        redirect_to admin_infomaniak_setting_path,
                    alert: "Authentifizierungsfehler: Der API-Token ist ungültig oder abgelaufen."
      else
        redirect_to admin_infomaniak_setting_path,
                    alert: "Infomaniak API antwortete mit Status #{response.code}."
      end
    rescue => e
      redirect_to admin_infomaniak_setting_path,
                  alert: "Verbindungsfehler: #{e.message}"
    end

    private

    def infomaniak_setting_params
      params.require(:infomaniak_setting).permit(
        :api_token, :mailing_list_id, :base_url, :active
      )
    end
  end
end
