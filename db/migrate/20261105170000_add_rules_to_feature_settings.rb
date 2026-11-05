# Globale Regeln/Fristen aus SettingsCatalog. Fehlt ein Schlüssel, gilt der
# Katalog-Default (= bisheriges, fest programmiertes Verhalten).
class AddRulesToFeatureSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :feature_settings, :rules, :jsonb, default: {}, null: false
  end
end
