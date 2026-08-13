require "test_helper"

class MailSettingTest < ActiveSupport::TestCase
  def teardown
    MailSetting.delete_all
  end

  test "mail_enabled? returns true when no record exists" do
    assert_equal true, MailSetting.mail_enabled?(:registration_confirmation)
    assert_equal true, MailSetting.mail_enabled?(:waitlist_promoted)
    assert_equal true, MailSetting.mail_enabled?(:cancelled_by_trainer)
    assert_equal true, MailSetting.mail_enabled?(:payment_expired)
    assert_equal true, MailSetting.mail_enabled?(:course_access_invited)
  end

  test "mail_enabled? returns true when setting exists with defaults" do
    MailSetting.create!
    assert_equal true, MailSetting.mail_enabled?(:registration_confirmation)
    assert_equal true, MailSetting.mail_enabled?(:waitlist_promoted)
  end

  test "mail_enabled? returns false when specific mail is disabled" do
    setting = MailSetting.create!(
      mail_registration_confirmation_enabled: false,
      mail_waitlist_promoted_enabled: true
    )
    assert_equal false, MailSetting.mail_enabled?(:registration_confirmation)
    assert_equal true,  MailSetting.mail_enabled?(:waitlist_promoted)
  end

  # ── Neu: generische notification_toggles-Spalte für alle nicht-legacy Keys ──

  test "notification_enabled? gibt true zurück, wenn kein Toggle gesetzt ist (Default: aktiv)" do
    setting = MailSetting.create!
    assert setting.notification_enabled?(:unsubscribe_reminder)
  end

  test "notification_enabled? gibt false zurück, wenn explizit deaktiviert" do
    setting = MailSetting.create!(notification_toggles: { "unsubscribe_reminder" => false })
    assert_not setting.notification_enabled?(:unsubscribe_reminder)
    assert setting.notification_enabled?(:trainer_assigned), "andere Keys bleiben unberührt"
  end

  test "set_notification_enabled! schreibt in die jsonb-Spalte für neue Keys" do
    setting = MailSetting.create!
    setting.set_notification_enabled!(:unsubscribe_reminder, false)
    assert_not setting.reload.notification_enabled?(:unsubscribe_reminder)
  end

  test "set_notification_enabled! schreibt in die Legacy-Boolean-Spalte für alte Keys" do
    setting = MailSetting.create!
    setting.set_notification_enabled!(:registration_confirmation, false)
    assert_not setting.reload.mail_registration_confirmation_enabled
  end

  test "with_preview_mode überschreibt mail_enabled? innerhalb des Blocks, auch für deaktivierte Mails" do
    MailSetting.create!(mail_registration_confirmation_enabled: false)
    assert_equal false, MailSetting.mail_enabled?(:registration_confirmation)

    result = MailSetting.with_preview_mode { MailSetting.mail_enabled?(:registration_confirmation) }
    assert_equal true, result

    assert_equal false, MailSetting.mail_enabled?(:registration_confirmation), "Guard muss nach dem Block wieder greifen"
  end

  test "with_preview_mode setzt das Flag auch bei einer Exception im Block zurück" do
    assert_raises(RuntimeError) do
      MailSetting.with_preview_mode { raise "boom" }
    end
    assert_equal false, Thread.current[:notification_preview_mode]
  end

  test "all mail toggle fields default to true" do
    setting = MailSetting.create!
    assert setting.mail_registration_confirmation_enabled
    assert setting.mail_waitlist_promoted_enabled
    assert setting.mail_cancelled_by_trainer_enabled
    assert setting.mail_payment_expired_enabled
    assert setting.mail_course_access_invited_enabled
  end

  test "mail toggle fields can be individually disabled" do
    setting = MailSetting.create!(
      mail_cancelled_by_trainer_enabled: false,
      mail_payment_expired_enabled: false
    )
    assert     setting.mail_registration_confirmation_enabled
    assert     setting.mail_waitlist_promoted_enabled
    assert_not setting.mail_cancelled_by_trainer_enabled
    assert_not setting.mail_payment_expired_enabled
    assert     setting.mail_course_access_invited_enabled
  end
end
