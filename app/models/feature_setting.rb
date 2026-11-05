# Globale Schalter und Regeln der App (Single-Row wie ClubSetting/MailSetting).
# Welche es gibt, beschreibt SettingsCatalog; Werte liegen in einer gleichnamigen
# Spalte (Altbestand: trainer_self_enroll_enabled) oder in der JSONB-Spalte rules.
class FeatureSetting < ApplicationRecord
  validate :rules_within_limits

  def self.current
    first_or_create!
  end

  # Wert einer Einstellung, Default aus dem Katalog, solange nichts gespeichert ist.
  def self.value(key) = current.value(key)

  def value(key)
    entry = SettingsCatalog.fetch(key)
    return self[entry.key] if has_attribute?(entry.key)

    rules.fetch(entry.key.to_s, entry.default)
  end

  # Übernimmt Formularwerte (nur Katalog-Schlüssel) in Spalte bzw. rules.
  def assign_catalog(params)
    SettingsCatalog::ENTRIES.each do |entry|
      next unless params.key?(entry.key.to_s)

      raw = params[entry.key.to_s]
      if has_attribute?(entry.key)
        self[entry.key] = raw
      else
        self.rules = rules.merge(entry.key.to_s => cast(entry, raw))
      end
    end
  end

  private

  def cast(entry, raw)
    entry.boolean? ? ActiveModel::Type::Boolean.new.cast(raw) : Integer(raw.to_s, exception: false)
  end

  def rules_within_limits
    SettingsCatalog::ENTRIES.reject(&:boolean?).each do |entry|
      next unless rules.key?(entry.key.to_s)

      v = rules[entry.key.to_s]
      next if v.is_a?(Integer) && v.between?(entry.min, entry.max)

      errors.add(:base, I18n.t("admin.settings.features.out_of_range", label: entry.label, min: entry.min, max: entry.max))
    end
  end
end
