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

    test "edit zeigt 'Training abgesagt' (Admin-Rolle) nicht für reine Trainer" do
      get edit_admin_notification_preferences_path
      assert_response :success
      assert_no_match "Training abgesagt", response.body
    end

    test "edit zeigt 'Training abgesagt' mit Admin-Rollen-Badge für Admins" do
      sign_out @trainer
      sign_in users(:admin)

      get edit_admin_notification_preferences_path
      assert_response :success
      assert_match "Training abgesagt", response.body
      assert_match "Als Admin", response.body
      assert_match "Als Trainer", response.body
    end
  end
end
