require "test_helper"

module Admin
  class NotificationPreferencesControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    setup do
      # User one ist als Trainer hinterlegt (Fixture trainers(:one)).
      @trainer = users(:one)
      sign_in @trainer
    end

    test "gefälschter POST mit attendance_reminder=0 bleibt wirkungslos" do
      patch admin_notification_preferences_path, params: {
        preferences: { "attendance_reminder" => "0", "cancel_notice" => "0" }
      }

      @trainer.reload
      assert @trainer.admin_notification_enabled?("attendance_reminder"),
             "Verpflichtende Erinnerung muss trotz gefälschtem POST aktiv bleiben"
      assert_equal true, @trainer.admin_notification_preferences["attendance_reminder"]
      assert_not @trainer.admin_notification_enabled?("cancel_notice"),
             "Optionaler Typ muss weiterhin abschaltbar sein"
    end
  end
end
