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
end
