module Admin
  class ClubSettingsController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!

    def show
      @club_setting = ClubSetting.current
    end

    def edit
      @club_setting = ClubSetting.current
    end

    def update
      @club_setting = ClubSetting.current

      if @club_setting.update(club_setting_params)
        redirect_to admin_club_setting_path, notice: "Vereinseinstellungen wurden gespeichert."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy_logo
      @club_setting = ClubSetting.current
      @club_setting.logo.purge
      redirect_to edit_admin_club_setting_path, notice: "Logo wurde entfernt."
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
