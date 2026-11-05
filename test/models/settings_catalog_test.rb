require "test_helper"

class SettingsCatalogTest < ActiveSupport::TestCase
  test "jeder Eintrag hat Texte in allen Sprachen und einen gültigen Default" do
    SettingsCatalog::ENTRIES.each do |entry|
      I18n.available_locales.each do |locale|
        base = "admin.settings.features"
        keys = %W[#{base}.entries.#{entry.key}.label #{base}.entries.#{entry.key}.desc #{base}.groups.#{entry.group}]
        keys << "#{base}.units.#{entry.unit}" unless entry.boolean?
        keys.each { |key| assert I18n.exists?(key, locale), "Text #{locale}.#{key} fehlt" }
      end
      next if entry.boolean?

      assert entry.min && entry.max && entry.unit, "#{entry.key} braucht min, max und unit"
      assert entry.default.between?(entry.min, entry.max), "Default von #{entry.key} liegt ausserhalb"
    end
  end

  test "value liefert Spaltenwert für Altbestand-Schalter" do
    setting = FeatureSetting.current
    setting.update!(trainer_self_enroll_enabled: false)
    assert_equal false, FeatureSetting.value(:trainer_self_enroll_enabled)
  end

  test "unbekannte Einstellung wirft einen Fehler" do
    assert_raises(KeyError) { FeatureSetting.value(:gibt_es_nicht) }
  end

  test "Zahlenwert wird gespeichert, ausserhalb der Grenzen abgelehnt" do
    setting = FeatureSetting.current
    assert_equal 12, setting.value(:mail_log_retention_months)

    setting.assign_catalog(ActionController::Parameters.new("mail_log_retention_months" => "3").permit!)
    assert setting.save
    assert_equal 3, FeatureSetting.value(:mail_log_retention_months)
    assert_equal 3.months, MailLog.retention

    %w[0 61 abc].each do |raw|
      setting.assign_catalog(ActionController::Parameters.new("mail_log_retention_months" => raw).permit!)
      assert_not setting.valid?, raw
    end
  end

  test "Präsenz-Fristen folgen den eingestellten Werten" do
    FeatureSetting.current.update!(rules: { "attendance_opens_before_hours" => 0,
                                            "attendance_trainer_reminder_hours" => 48,
                                            "attendance_admin_alert_days" => 3 })
    session = training_sessions(:one)

    session.assign_attributes(start_time: 30.minutes.from_now)
    assert_not session.attendance_open?, "0 Stunden: erst ab Beginn"

    session.assign_attributes(start_time: 30.hours.ago, end_time: 30.hours.ago, trainer_reminded_at: nil,
                              admin_notified_at: nil, attendance_confirmed_at: nil, is_canceled: false)
    assert_not session.needs_trainer_reminder?, "48 Stunden noch nicht erreicht"

    session.assign_attributes(end_time: 4.days.ago)
    assert session.needs_trainer_reminder?
    assert session.needs_admin_notification?, "3 Tage überschritten"
  end

  test "Wartelisten-Frist steht in der Mail und bestimmt den Ablauf" do
    FeatureSetting.current.update!(rules: { "waitlist_offer_days" => 9 })
    registration = course_registrations(:one)
    registration.update_columns(status: "platz_frei")

    mail = CourseRegistrationMailer.waitlist_promoted(registration)
    assert_match "innerhalb von 9 Tagen", mail.text_part.body.to_s
    assert_match "9 Tagen", mail.html_part.body.to_s
  end

  test "Schnupperfrist bestimmt Ablaufdatum und steht in der Bestätigungsmail" do
    FeatureSetting.current.update!(rules: { "trial_expiry_days" => 10 })
    assert_equal 10.days, CourseRegistration.trial_period

    registration = course_registrations(:one)
    registration.update_columns(status: "schnuppern", trial_expires_at: nil, created_at: 7.days.ago)
    assert_not registration.reload.trial_expired?, "7 Tage < 10 Tage Frist"
    registration.update_columns(created_at: 11.days.ago)
    assert registration.reload.trial_expired?

    mail = CourseRegistrationMailer.confirmation(registration)
    assert_match "für 10 Tage gesichert", mail.text_part.body.to_s
  end
end
