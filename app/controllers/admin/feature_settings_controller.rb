module Admin
  class FeatureSettingsController < ApplicationController
    include SettingsLoadable

    before_action :authenticate_user!
    before_action :authorize_admin!

    def update
      @feature_setting = FeatureSetting.current
      if @feature_setting.update(feature_setting_params)
        redirect_to admin_settings_features_path, notice: "Funktionseinstellungen wurden gespeichert."
      else
        render "admin/settings/features", status: :unprocessable_entity
      end
    end

    private

    def feature_setting_params
      params.require(:feature_setting).permit(:trainer_self_enroll_enabled)
    end
  end
end
