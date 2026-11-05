require "test_helper"

# Absicherung für den Admin-Umbau (docs/admin-architektur-plan.md, Schritt 0):
# Jede heutige Admin-Seite bleibt für Admins erreichbar, für alle anderen nicht,
# und jede Seite aus dem Schnellzugriff ist auf der Kommandozentrale verlinkt.
class AdminAccessTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  ADMIN_ONLY_PAGES = %i[
    dashboards_admin_path dashboards_stats_path talents_dashboard_path open_attendances_dashboard_path
    admin_settings_path admin_settings_communication_path admin_settings_club_path
    admin_settings_payments_path admin_settings_features_path open_payments_dashboard_path
    admin_export_profiles_path new_admin_export_profile_path admin_nds_path admin_reports_path
    admin_supplementary_charges_path new_admin_supplementary_charge_path
    admin_age_exemptions_path admin_notifications_path
    trainers_path new_trainer_path substitutes_trainers_path
    holiday_types_path new_holiday_type_path terms_path new_term_path course_categories_path
    newsletters_path new_newsletter_path newsletter_subscribers_path new_course_path
  ].freeze

  # Für Trainer:innen freigegeben, für Eltern nicht.
  STAFF_PAGES = %i[edit_admin_notification_preferences_path mail_logs_path].freeze

  # Alte Einzelseiten, die auf ihren Einstellungs-Tab weiterleiten.
  LEGACY_REDIRECTS = {
    admin_payment_setting_path: :admin_settings_payments_path,
    admin_infomaniak_setting_path: :admin_settings_communication_path,
    admin_club_setting_path: :admin_settings_club_path,
    mail_setting_path: :admin_settings_communication_path,
    admin_settings_data_path: "/dashboards/admin#bereich-analysis"
  }.freeze

  # Alles, was die Kommandozentrale heute verlinkt, muss erreichbar bleiben.
  DASHBOARD_LINKS = %i[
    trainers_path holiday_types_path terms_path open_attendances_dashboard_path
    course_categories_path admin_supplementary_charges_path admin_age_exemptions_path
    dashboards_stats_path talents_dashboard_path
    admin_settings_communication_path admin_settings_club_path admin_settings_payments_path
    admin_settings_features_path new_course_path
    newsletters_path newsletter_subscribers_path mail_logs_path
    admin_reports_path admin_nds_path admin_export_profiles_path
  ].freeze

  # Reine Arbeitsseiten gehören nicht in die Einstellungen.
  test "Einstellungs-Tab Kommunikation verlinkt keine Newsletter-Arbeitsseiten mehr" do
    sign_in users(:admin)
    get admin_settings_communication_path
    assert_select "main a[href='#{newsletters_path}']", 0
    assert_select "main a[href='#{newsletter_subscribers_path}']", 0
  end

  test "Admin erreicht jede Admin-Seite" do
    sign_in users(:admin)
    (ADMIN_ONLY_PAGES + STAFF_PAGES).each do |helper|
      get public_send(helper)
      assert_response :success, "#{helper} sollte für Admins erreichbar sein"
    end
  end

  test "alte Einzelseiten leiten weiter" do
    sign_in users(:admin)
    LEGACY_REDIRECTS.each do |from, to|
      get public_send(from)
      assert_redirected_to(to.is_a?(Symbol) ? public_send(to) : to)
    end
  end

  test "Trainer:innen und Eltern erreichen keine Admin-Seite" do
    [ users(:one), users(:parent_only) ].each do |user|
      sign_in user
      ADMIN_ONLY_PAGES.each do |helper|
        get public_send(helper)
        assert_response :redirect, "#{helper} darf #{user.email} nicht anzeigen"
      end
      sign_out user
    end
  end

  test "Eltern erreichen keine Trainer-Seite im Admin-Bereich" do
    sign_in users(:parent_only)
    STAFF_PAGES.each do |helper|
      get public_send(helper)
      assert_response :redirect, "#{helper} darf Eltern nicht angezeigt werden"
    end
  end

  test "ohne Login wird jede Admin-Seite zum Login umgeleitet" do
    (ADMIN_ONLY_PAGES + STAFF_PAGES).each do |helper|
      get public_send(helper)
      assert_response :redirect, "#{helper} braucht ein Login"
    end
  end

  test "Nicht-Admin bekommt bei unbekannter ID eine Umleitung statt 404" do
    sign_in users(:parent_only)
    get edit_term_path(id: 0)
    assert_response :redirect
    get edit_trainer_path(id: 0)
    assert_response :redirect
  end

  test "Kommandozentrale verlinkt jede Seite aus dem Schnellzugriff" do
    sign_in users(:admin)
    get dashboards_admin_path
    DASHBOARD_LINKS.each do |helper|
      assert_select "a[href='#{public_send(helper)}']", { minimum: 1 }, "Link #{helper} fehlt"
    end
  end

  test "jede Bereichsseite zeigt Zurück zur Kommandozentrale und die Tabs ihres Bereichs" do
    sign_in users(:admin)
    AdminNavigation::SECTIONS.each do |section, items|
      items.each do |item|
        get public_send(item.path)
        assert_response :success, item.key
        assert_select "a[href='#{dashboards_admin_path}']", { minimum: 1 }, "Zurück-Link fehlt auf #{item.key}"
        nav = "nav[aria-label='#{I18n.t("dashboards.admin.sections.#{section}")}']"
        assert_select "#{nav} a", items.size, "Tabs fehlen auf #{item.key}"
        assert_select "#{nav} a[aria-current=page][href='#{public_send(item.path)}']", 1, "aktiver Tab fehlt auf #{item.key}"
      end
    end
  end

  test "Trainer:innen sehen im Mail-Protokoll keinen Admin-Bereichskopf" do
    sign_in users(:one)
    get mail_logs_path
    assert_response :success
    assert_select "nav[aria-label='#{I18n.t("dashboards.admin.sections.communication")}']", 0
  end

  test "lange Listen zeigen eine Höchstzahl und „Mehr anzeigen“" do
    sign_in users(:admin)
    25.times { |i| Term.create!(name: "T#{i}", kind: "semester", start_date: Date.new(2000 + i, 1, 1), end_date: Date.new(2000 + i, 6, 30)) }
    total = Term.count

    get terms_path
    assert_select "a", text: I18n.t("shared.load_more.button"), count: 1
    assert_match I18n.t("shared.load_more.shown", shown: 20, total: total), response.body

    get terms_path(page: 2)
    assert_select "a", text: I18n.t("shared.load_more.button"), count: 0
  end

  test "Ferientage: pro Art die neuesten 10, Rest über „Alle anzeigen“" do
    sign_in users(:admin)
    type = HolidayType.create!(name: "Viele Ferien")
    12.times { |i| type.holidays.create!(start_date: Date.new(2010 + i, 7, 1), end_date: Date.new(2010 + i, 7, 10)) }

    get holiday_types_path
    assert_select "##{ActionView::RecordIdentifier.dom_id(type)} li", 10
    get holiday_types_path(alle: type.id)
    assert_select "##{ActionView::RecordIdentifier.dom_id(type)} li", 12
  end

  test "Sidebar: Admin-Dashboard klappt Übersicht und alle Bereiche auf, offen im Admin-Bereich" do
    sign_in users(:admin)
    get terms_path
    assert_select ".nav-disclosure[data-open] #admin-subnav a.nav-subitem", AdminNavigation::SECTIONS.size + 1
    assert_select "#admin-subnav a[href='#{dashboards_admin_path}']"
    AdminNavigation::SECTIONS.each_value do |items|
      assert_select "#admin-subnav a[href='#{public_send(items.first.path)}']"
    end
    assert_select "#admin-subnav a[aria-current=page]", text: I18n.t("dashboards.admin.sections.courses")

    get courses_path
    assert_select ".nav-disclosure", 1
    assert_select ".nav-disclosure[data-open]", 0
  end
end
