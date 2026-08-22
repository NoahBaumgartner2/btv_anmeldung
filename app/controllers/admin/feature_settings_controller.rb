module Admin
  class FeatureSettingsController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!

    def update
      FeatureSetting.current.update!(feature_setting_params)
      redirect_to dashboards_admin_path, notice: "Funktionseinstellungen wurden gespeichert."
    end

    private

    def feature_setting_params
      params.require(:feature_setting).permit(:trainer_self_enroll_enabled)
    end
  end
end
