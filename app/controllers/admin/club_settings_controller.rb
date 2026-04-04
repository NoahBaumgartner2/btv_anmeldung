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
        if params[:club_setting][:logo].present?
          @club_setting.logo.attach(params[:club_setting][:logo])
        end
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
      params.require(:club_setting).permit(:club_name, :primary_color, :secondary_color)
    end
  end
end
