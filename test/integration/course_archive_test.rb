require "test_helper"

# Archiv-Seite der Kommandozentrale (Bereich Kurse › Archiv).
class CourseArchiveTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def course(title, **attrs)
    Course.new(title: title, registration_type: "semester", registration_mode: "semester", has_payment: false,
               has_ticketing: false, allows_holiday_deduction: false, **attrs).tap { |c| c.save!(validate: false) }
  end

  test "archived/not_archived entsprechen genau Course#ended?, auch an der Tagesgrenze" do
    today = Time.current.beginning_of_day
    cases = [
      course("gestern", end_date: today - 1.minute),
      course("heute früh", end_date: today + 1.minute),
      course("morgen", end_date: today + 1.day),
      course("ohne Ende", end_date: nil),
      course("deaktiviert", end_date: today + 1.day, deactivated_at: Time.current)
    ]
    cases.each do |c|
      assert_equal c.ended?, Course.archived.exists?(c.id), "archived: #{c.title}"
      assert_equal !c.ended?, Course.not_archived.exists?(c.id), "not_archived: #{c.title}"
    end
  end

  test "Filter nach Suche, Zeitraum, Kategorie und Status" do
    sign_in users(:admin)
    course("Turnen alt", end_date: 1.month.ago, term: terms(:one), category: "Turnen")
    course("Pilates alt", end_date: 2.months.ago, category: "Pilates")
    course("Stillgelegt", end_date: 1.month.from_now, deactivated_at: 1.day.ago, category: "Turnen")
    course("Läuft", end_date: 1.month.from_now)

    get archive_dashboard_path
    %w[Turnen\ alt Pilates\ alt Stillgelegt].each { |t| assert_match t, response.body }
    assert_no_match "Läuft", response.body

    get archive_dashboard_path(q: "pila")
    assert_match "Pilates alt", response.body
    assert_no_match "Turnen alt", response.body

    get archive_dashboard_path(term_id: "none")
    assert_match "Pilates alt", response.body
    assert_no_match "Turnen alt", response.body

    get archive_dashboard_path(term_id: terms(:one).id)
    assert_match "Turnen alt", response.body
    assert_no_match "Pilates alt", response.body

    get archive_dashboard_path(category: "Turnen", status: "deactivated")
    assert_match "Stillgelegt", response.body
    assert_no_match "Turnen alt", response.body
  end

  test "zeigt höchstens 30 Kurse, Rest über „Mehr anzeigen“" do
    sign_in users(:admin)
    32.times { |i| course("Alt #{i}", end_date: (i + 1).days.ago) }
    total = Course.archived.count

    get archive_dashboard_path
    assert_match I18n.t("shared.load_more.shown", shown: 30, total: total), response.body
    get archive_dashboard_path(page: 2)
    assert_select "a", text: I18n.t("shared.load_more.button"), count: 0
  end

  test "nur für Admins" do
    sign_in users(:parent_only)
    get archive_dashboard_path
    assert_response :redirect
  end
end
