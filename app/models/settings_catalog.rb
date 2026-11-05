# Zentrales Verzeichnis aller globalen Schalter und Regeln (Seite
# Einstellungen › Funktionen & Regeln). Muster wie NotificationCatalog.
#
# Neuer globaler Schalter/Wert = 1 Entry hier + Texte unter
# admin.settings.features.entries.<key>.label/desc. Formular, Speicherung
# (FeatureSetting#rules, JSONB) und Abfrage (FeatureSetting.value(:key))
# leiten sich daraus ab. Boolean-Einträge mit gleichnamiger Spalte auf
# feature_settings (Altbestand) werden in der Spalte gespeichert.
class SettingsCatalog
  Entry = Data.define(:key, :type, :default, :group, :min, :max, :unit) do
    def initialize(key:, type:, default:, group:, min: nil, max: nil, unit: nil) = super
    def boolean? = type == :boolean
    def label = I18n.t("admin.settings.features.entries.#{key}.label")
    def description = I18n.t("admin.settings.features.entries.#{key}.desc")
  end

  ENTRIES = [
    Entry.new(key: :trainer_self_enroll_enabled, type: :boolean, default: true, group: :trainers),
    Entry.new(key: :waitlist_offer_days, type: :integer, default: 5, group: :registration, min: 1, max: 30, unit: :days),
    Entry.new(key: :attendance_opens_before_hours, type: :integer, default: 1, group: :attendance, min: 0, max: 24, unit: :hours),
    Entry.new(key: :attendance_trainer_reminder_hours, type: :integer, default: 24, group: :attendance, min: 1, max: 168, unit: :hours),
    Entry.new(key: :attendance_admin_alert_days, type: :integer, default: 7, group: :attendance, min: 1, max: 60, unit: :days),
    Entry.new(key: :mail_log_retention_months, type: :integer, default: 12, group: :data, min: 1, max: 60, unit: :months)
  ].freeze

  def self.fetch(key) = ENTRIES.find { |entry| entry.key == key.to_sym } || raise(KeyError, "Unbekannte Einstellung: #{key}")
  def self.groups = ENTRIES.group_by(&:group)
  def self.keys = ENTRIES.map(&:key)
end
