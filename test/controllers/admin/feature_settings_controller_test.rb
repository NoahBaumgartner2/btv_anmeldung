require "test_helper"

class Admin::FeatureSettingsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "Admin kann den globalen Trainer-Selbstanmeldung-Schalter umschalten" do
    sign_in users(:admin)

    patch admin_feature_setting_path, params: { feature_setting: { trainer_self_enroll_enabled: "0" } }

    assert_redirected_to admin_settings_features_path
    assert_not FeatureSetting.current.trainer_self_enroll_enabled?
  end

  test "Nicht-Admins können die Funktionseinstellungen nicht ändern" do
    sign_in users(:one)

    patch admin_feature_setting_path, params: { feature_setting: { trainer_self_enroll_enabled: "0" } }

    assert_redirected_to root_path
    assert FeatureSetting.current.trainer_self_enroll_enabled?
  end
end
