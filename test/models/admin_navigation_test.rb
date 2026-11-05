require "test_helper"

class AdminNavigationTest < ActiveSupport::TestCase
  test "jede Admin-Seite hat Route, Farbschema und Texte in allen Sprachen" do
    AdminNavigation::SECTIONS.each do |section, items|
      items.each do |item|
        assert_kind_of String, Rails.application.routes.url_helpers.public_send(item.path), "Route #{item.path} fehlt"
        assert AdminNavigation::TONES.key?(item.tone), "Farbschema #{item.tone} fehlt"
        assert item.icon || item.emoji, "#{item.key} braucht icon oder emoji"
        I18n.available_locales.each do |locale|
          %W[dashboards.admin.links.#{item.key} dashboards.admin.links.#{item.key}_desc dashboards.admin.sections.#{section}].each do |key|
            assert I18n.exists?(key, locale), "Text #{locale}.#{key} fehlt"
          end
          assert I18n.exists?("admin.settings.tabs.#{item.tab}", locale), "Tab-Text #{locale} #{item.tab} fehlt" if item.tab
        end
      end
    end
  end
end
