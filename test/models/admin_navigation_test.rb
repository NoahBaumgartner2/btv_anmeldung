require "test_helper"

class AdminNavigationTest < ActiveSupport::TestCase
  test "jede Admin-Seite hat Route, Farbschema und Texte in allen Sprachen" do
    AdminNavigation::SECTIONS.each do |section, items|
      assert AdminNavigation::TONES.key?(AdminNavigation::SECTION_TONES[section]), "Farbe für #{section} fehlt"
      items.each do |item|
        assert_kind_of String, Rails.application.routes.url_helpers.public_send(item.path), "Route #{item.path} fehlt"
        assert item.icon.present?, "#{item.key} braucht ein SVG-Icon"
        I18n.available_locales.each do |locale|
          %W[dashboards.admin.links.#{item.key} dashboards.admin.links.#{item.key}_desc dashboards.admin.sections.#{section}].each do |key|
            assert I18n.exists?(key, locale), "Text #{locale}.#{key} fehlt"
          end
        end
      end
    end
  end
end
