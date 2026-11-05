module Admin
  class FeatureSettingsController < BaseController
    include SettingsLoadable

    def update
      @feature_setting = FeatureSetting.current
      @feature_setting.assign_catalog(feature_setting_params)
      if @feature_setting.save
        redirect_to admin_settings_features_path, notice: "Funktionseinstellungen wurden gespeichert."
      else
        render "admin/settings/features", status: :unprocessable_entity
      end
    end

    private

    def feature_setting_params
      params.require(:feature_setting).permit(*SettingsCatalog.keys)
    end
  end
end
