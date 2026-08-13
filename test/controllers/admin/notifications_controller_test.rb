require "test_helper"

class Admin::NotificationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:admin)
    sign_in @admin
  end

  test "index zeigt alle Katalog-Einträge gruppiert nach Kategorie" do
    get admin_notifications_path
    assert_response :success
    assert_select "h2", minimum: 2 # mind. 2 Kategorien-Überschriften
  end

  test "index verweigert Zugriff für Nicht-Admins" do
    sign_out @admin
    sign_in users(:one)

    get admin_notifications_path
    assert_redirected_to root_path
  end

  test "preview rendert die echte Mail-Vorlage mit Beispieldaten" do
    get preview_admin_notification_path("registration_confirmation")
    assert_response :success
    assert_match "Max Muster", response.body
  end

  test "preview mit unbekanntem Key liefert 404" do
    get preview_admin_notification_path("does_not_exist")
    assert_response :not_found
  end

  test "toggle schaltet einen neuen (jsonb-basierten) Benachrichtigungstyp aus" do
    patch toggle_admin_notification_path("unsubscribe_reminder"), params: { enabled: "0" }, as: :json
    assert_response :success
    assert_not MailSetting.current.notification_enabled?(:unsubscribe_reminder)
  end

  test "toggle schaltet einen Legacy-Benachrichtigungstyp aus" do
    patch toggle_admin_notification_path("registration_confirmation"), params: { enabled: "0" }, as: :json
    assert_response :success
    assert_not MailSetting.current.mail_registration_confirmation_enabled
  end

  test "toggle verweigert Deaktivierung für nicht-abschaltbare Mails" do
    patch toggle_admin_notification_path("devise_confirmation"), params: { enabled: "0" }
    assert_redirected_to admin_notifications_path
    assert MailSetting.current.notification_enabled?(:devise_confirmation)
  end
end
