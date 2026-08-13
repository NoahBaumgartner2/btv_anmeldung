require "test_helper"

class NotificationCatalogTest < ActiveSupport::TestCase
  test "jeder Eintrag hat einen eindeutigen Key" do
    keys = NotificationCatalog.all.map(&:key)
    assert_equal keys.uniq.size, keys.size, "Keys müssen eindeutig sein: #{keys}"
  end

  test "jeder Eintrag hat Name, Beschreibung und Empfänger-Text hinterlegt" do
    NotificationCatalog.all.each do |entry|
      assert entry.name.present?, "#{entry.key}: name fehlt"
      assert entry.description.present?, "#{entry.key}: description fehlt"
      assert entry.recipient.present?, "#{entry.key}: recipient fehlt"
    end
  end

  test "jeder toggleable Eintrag hat eine preview_method" do
    NotificationCatalog.all.select(&:toggleable).each do |entry|
      assert entry.preview_method.present?, "#{entry.key}: toggleable, aber keine preview_method"
    end
  end

  test "find liefert den passenden Eintrag per String oder Symbol" do
    assert_equal "registration_confirmation", NotificationCatalog.find("registration_confirmation").key
    assert_equal "registration_confirmation", NotificationCatalog.find(:registration_confirmation).key
    assert_nil NotificationCatalog.find("does_not_exist")
  end

  test "by_category gruppiert alle Einträge ohne Verlust" do
    grouped = NotificationCatalog.by_category
    total = grouped.sum { |_, entries| entries.size }
    assert_equal NotificationCatalog.all.size, total
  end

  test "devise-Mails sind nicht abschaltbar" do
    assert_not NotificationCatalog.find("devise_confirmation").toggleable
    assert_not NotificationCatalog.find("devise_password_reset").toggleable
  end
end
