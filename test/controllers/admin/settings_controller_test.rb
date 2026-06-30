require "test_helper"

module Admin
  class SettingsControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    setup do
      @admin = users(:admin)
      @parent = users(:one)
    end

    # ── Hub-Tabs: Admin sieht jeden Tab ──────────────────────────────────
    test "admin kann jeden Einstellungs-Tab öffnen" do
      sign_in @admin

      get admin_settings_communication_path
      assert_response :success

      get admin_settings_club_path
      assert_response :success

      get admin_settings_payments_path
      assert_response :success

      get admin_settings_data_path
      assert_response :success
    end

    test "admin_settings_path zeigt auf den Kommunikation-Tab" do
      sign_in @admin
      get admin_settings_path
      assert_response :success
    end

    # ── Türsteher: Nicht-Admins werden abgewiesen ────────────────────────
    test "nicht-admin wird vom Einstellungs-Hub umgeleitet" do
      sign_in @parent

      get admin_settings_communication_path
      assert_redirected_to root_path

      get admin_settings_club_path
      assert_redirected_to root_path

      get admin_settings_payments_path
      assert_redirected_to root_path

      get admin_settings_data_path
      assert_redirected_to root_path
    end

    test "anonymer Besuch wird zum Login umgeleitet" do
      get admin_settings_communication_path
      assert_redirected_to new_user_session_path
    end

    # ── Alte Singleton-URLs leiten auf die neuen Tabs um ─────────────────
    test "alte Singleton-Seiten leiten auf den passenden Tab um" do
      sign_in @admin

      get mail_setting_path
      assert_redirected_to admin_settings_communication_path

      get edit_mail_setting_path
      assert_redirected_to admin_settings_communication_path

      get admin_infomaniak_setting_path
      assert_redirected_to admin_settings_communication_path

      get edit_admin_infomaniak_setting_path
      assert_redirected_to admin_settings_communication_path

      get admin_club_setting_path
      assert_redirected_to admin_settings_club_path

      get edit_admin_club_setting_path
      assert_redirected_to admin_settings_club_path

      get admin_payment_setting_path
      assert_redirected_to admin_settings_payments_path

      get edit_admin_payment_setting_path
      assert_redirected_to admin_settings_payments_path
    end
  end
end
