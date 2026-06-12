require "test_helper"

class CourseTest < ActiveSupport::TestCase
  def base_attrs
    {
      title: "Test Kurs",
      registration_type: "semester",
      registration_mode: "semester",
      has_payment: false,
      has_ticketing: false,
      allows_holiday_deduction: false
    }
  end

  test "allows_trial is valid regardless of requires_ahv_number" do
    course = Course.new(base_attrs.merge(allows_trial: true, requires_ahv_number: false))
    assert course.valid?, course.errors.full_messages.inspect
  end

  test "allows_trial false is valid regardless of requires_ahv_number" do
    course = Course.new(base_attrs.merge(allows_trial: false, requires_ahv_number: false))
    assert course.valid?, course.errors.full_messages.inspect
  end

  test "allows_trial defaults to false" do
    course = Course.new(base_attrs)
    assert_equal false, course.allows_trial
  end

  # ── Preisreduktion ───────────────────────────────────────────────────────────

  def paid_attrs
    base_attrs.merge(has_payment: true, price_cents: 10_000)
  end

  test "discounts_enabled ohne Beträge ist ungültig" do
    course = Course.new(paid_attrs.merge(discounts_enabled: true))
    assert_not course.valid?
    assert course.errors[:base].any?
  end

  test "discounts_enabled mit einem gesetzten Betrag ist gültig" do
    course = Course.new(paid_attrs.merge(discounts_enabled: true, sibling_price_cents: 6_000))
    assert course.valid?, course.errors.full_messages.inspect
  end

  test "Rabattpreis gleich oder über Kurspreis ist ungültig" do
    course = Course.new(paid_attrs.merge(discounts_enabled: true, sibling_price_cents: 10_000))
    assert_not course.valid?
    assert course.errors[:sibling_price_cents].any?
  end

  test "negativer Rabattpreis ist ungültig" do
    course = Course.new(paid_attrs.merge(discounts_enabled: true, second_course_price_cents: -100))
    assert_not course.valid?
    assert course.errors[:second_course_price_cents].any?
  end

  test "ohne discounts_enabled werden Rabattfelder nicht validiert" do
    course = Course.new(paid_attrs.merge(discounts_enabled: false, sibling_price_cents: 99_000))
    assert course.valid?, course.errors.full_messages.inspect
  end

  test "sibling_price_chf konvertiert CHF in Cents und zurück" do
    course = Course.new(paid_attrs)
    course.sibling_price_chf = "60.50"
    assert_equal 6_050, course.sibling_price_cents
    assert_equal "60.50", course.sibling_price_chf
    assert_equal "CHF 60.50", course.sibling_price_display
  end

  # ── weekly_sort_key / representative_session ─────────────────────────────────

  def course_with_session(title, day, hour, minute: 0, canceled: false)
    course = Course.new(base_attrs.merge(title: title))
    course.save!(validate: false)
    date = Date.current.next_occurring(day)
    start_time = Time.zone.local(date.year, date.month, date.day, hour, minute)
    course.training_sessions.create!(start_time: start_time, end_time: start_time + 90.minutes, is_canceled: canceled)
    course
  end

  test "weekly_sort_key sortiert Montag 17:00 vor Montag 18:00 vor Dienstag 09:00" do
    monday_late   = course_with_session("Montag spät", :monday, 18)
    tuesday_early = course_with_session("Dienstag früh", :tuesday, 9)
    monday_early  = course_with_session("Montag früh", :monday, 17)

    sorted = [ monday_late, tuesday_early, monday_early ].sort_by(&:weekly_sort_key)
    assert_equal [ "Montag früh", "Montag spät", "Dienstag früh" ], sorted.map(&:title)
  end

  test "Kurs ohne Sessions kommt ans Ende" do
    no_sessions = Course.new(base_attrs.merge(title: "Ohne Sessions"))
    no_sessions.save!(validate: false)
    sunday = course_with_session("Sonntag", :sunday, 20)

    assert_equal [ 7, 0 ], no_sessions.weekly_sort_key
    sorted = [ no_sessions, sunday ].sort_by(&:weekly_sort_key)
    assert_equal [ "Sonntag", "Ohne Sessions" ], sorted.map(&:title)
  end

  test "abgesagte Sessions werden für den Sortierschlüssel ignoriert" do
    course = course_with_session("Mit Absage", :monday, 17, canceled: true)
    date = Date.current.next_occurring(:wednesday)
    course.training_sessions.create!(
      start_time: Time.zone.local(date.year, date.month, date.day, 10, 0),
      end_time: Time.zone.local(date.year, date.month, date.day, 11, 0),
      is_canceled: false
    )

    assert_equal 2, course.weekly_sort_key.first, "Mittwoch (Index 2) erwartet, abgesagter Montag darf nicht zählen"
  end

  test "representative_session bevorzugt kommende Session vor vergangener" do
    course = Course.new(base_attrs.merge(title: "Mit Vergangenheit"))
    course.save!(validate: false)
    past = course.training_sessions.create!(start_time: 2.weeks.ago, end_time: 2.weeks.ago + 1.hour)
    upcoming = course.training_sessions.create!(start_time: 1.week.from_now, end_time: 1.week.from_now + 1.hour)

    assert_equal upcoming, course.representative_session
    assert_not_equal past, course.representative_session
  end
end
