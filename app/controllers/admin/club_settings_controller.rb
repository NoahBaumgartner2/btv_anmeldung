module Admin
  class ClubSettingsController < ApplicationController
    include SettingsLoadable

    before_action :authenticate_user!
    before_action :authorize_admin!

    # Vereinseinstellungen leben jetzt im Verein-Tab des Einstellungs-Hubs.
    def show
      redirect_to admin_settings_club_path
    end

    def edit
      redirect_to admin_settings_club_path
    end

    def update
      @club_setting = ClubSetting.current

      if @club_setting.update(club_setting_params)
        redirect_to admin_settings_club_path, notice: "Vereinseinstellungen wurden gespeichert."
      else
        load_club_settings
        render "admin/settings/club", status: :unprocessable_entity
      end
    end

    def destroy_logo
      @club_setting = ClubSetting.current
      @club_setting.logo.purge
      redirect_to admin_settings_club_path, notice: "Logo wurde entfernt."
    end

    private

    def club_setting_params
      params.require(:club_setting).permit(
        :club_name, :primary_color, :secondary_color, :logo,
        :contact_street, :contact_zip, :contact_city,
        :contact_email, :contact_website, :contact_phone,
        :legal_form, :responsible_name, :responsible_function,
        :privacy_officer_name, :privacy_officer_email,
        :hosting_provider, :hosting_country,
        :smtp_provider, :payment_provider
      )
    end
  end
end
