require "test_helper"

class MailSettingTest < ActiveSupport::TestCase
  def teardown
    MailSetting.delete_all
  end

  test "mail_enabled? returns true when no record exists" do
    assert_equal true, MailSetting.mail_enabled?(:mail_registration_confirmation)
    assert_equal true, MailSetting.mail_enabled?(:mail_waitlist_promoted)
    assert_equal true, MailSetting.mail_enabled?(:mail_cancelled_by_trainer)
    assert_equal true, MailSetting.mail_enabled?(:mail_payment_expired)
    assert_equal true, MailSetting.mail_enabled?(:mail_course_access_invited)
  end

  test "mail_enabled? returns true when setting exists with defaults" do
    MailSetting.create!
    assert_equal true, MailSetting.mail_enabled?(:mail_registration_confirmation)
    assert_equal true, MailSetting.mail_enabled?(:mail_waitlist_promoted)
  end

  test "mail_enabled? returns false when specific mail is disabled" do
    setting = MailSetting.create!(
      mail_registration_confirmation_enabled: false,
      mail_waitlist_promoted_enabled: true
    )
    assert_equal false, MailSetting.mail_enabled?(:mail_registration_confirmation)
    assert_equal true,  MailSetting.mail_enabled?(:mail_waitlist_promoted)
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
