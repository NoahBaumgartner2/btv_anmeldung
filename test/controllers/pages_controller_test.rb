require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def make_course(title:, category:)
    Course.new(
      title: title, category: category,
      registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      start_date: Date.tomorrow, end_date: 1.year.from_now.to_date
    ).tap { |c| c.save!(validate: false) }
  end

  test "nicht angemeldet: Startseite zeigt Kurskategorien statt einzelner Kurse" do
    make_course(title: "Turnen Montag", category: "Turnen")
    make_course(title: "Turnen Mittwoch", category: "Turnen")
    make_course(title: "Schwimmen Dienstag", category: "Schwimmen")

    get root_path

    assert_response :success
    assert_select "a[href=?]", courses_path(anchor: "turnen")
    assert_select "a[href=?]", courses_path(anchor: "schwimmen")
    # Zwei Kurse derselben Kategorie ergeben eine Kategorie-Karte, nicht zwei Kurs-Karten
    assert_select "a[href=?]", courses_path(anchor: "turnen"), count: 1
  end

  test "angemeldet: Startseite leitet weiter statt Kurse zu zeigen" do
    sign_in users(:parent_only)

    get root_path

    assert_redirected_to participants_path
  end

  test "Startseite zeigt keine Kategorien von Kursen auf Einladung" do
    Course.new(title: "Geheimkurs Leistung", category: "Leistungsgruppe", restricted: true,
      registration_type: "semester", registration_mode: "semester", has_payment: false, has_ticketing: false,
      allows_holiday_deduction: false, end_date: Date.current + 30, public_registration_days: 365).save!(validate: false)

    get root_url
    assert_response :success
    assert_not_includes response.body, "Leistungsgruppe"
  end
end
