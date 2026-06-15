require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "admin_notification_enabled? ist für verpflichtende Typen immer true" do
    user = users(:one)
    user.admin_notification_preferences = { "attendance_reminder" => false }

    assert user.admin_notification_enabled?("attendance_reminder"),
           "Verpflichtende Erinnerung darf nicht abschaltbar sein"
    assert user.admin_notification_enabled?(:attendance_reminder),
           "Symbol-Argument muss ebenfalls greifen"
  end

  test "admin_notification_enabled? respektiert die Einstellung für optionale Typen" do
    user = users(:one)
    user.admin_notification_preferences = { "cancel_notice" => false }

    assert_not user.admin_notification_enabled?("cancel_notice")
    assert user.admin_notification_enabled?("session_unsubscription"), "Default ist aktiv"
  end
end
