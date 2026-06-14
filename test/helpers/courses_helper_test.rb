require "test_helper"

class CoursesHelperTest < ActionView::TestCase
  def make_course(title: "Helper-Kurs", registration_mode: "semester")
    course = Course.new(title: title, registration_type: "semester",
      registration_mode: registration_mode, has_payment: false,
      has_ticketing: false, allows_holiday_deduction: false)
    course.save!(validate: false)
    course
  end

  def add_session(course, day, hour, minute: 0, with_end: true, canceled: false)
    date = Date.current.next_occurring(day)
    start_time = Time.zone.local(date.year, date.month, date.day, hour, minute)
    course.training_sessions.create!(
      start_time: start_time,
      end_time: with_end ? start_time + 90.minutes : nil,
      is_canceled: canceled
    )
  end

  test "course_weekly_time zeigt Wochentag und Zeitbereich" do
    course = make_course
    add_session(course, :monday, 17)

    assert_equal "Montag, 17:00–18:30", course_weekly_time(course)
  end

  test "course_weekly_time zeigt nur Startzeit ohne end_time" do
    course = make_course
    add_session(course, :tuesday, 9, minute: 30, with_end: false)

    assert_equal "Dienstag, 09:30", course_weekly_time(course)
  end

  test "course_weekly_time ist nil ohne Sessions" do
    assert_nil course_weekly_time(make_course)
  end

  test "course_weekly_time ist nil bei Drop-In mit unterschiedlichen Wochentagen" do
    course = make_course(registration_mode: "single_session")
    add_session(course, :monday, 17)
    add_session(course, :thursday, 19)

    assert_nil course_weekly_time(course)
  end

  test "course_weekly_time zeigt Zeile bei Drop-In mit einheitlichem Wochenrhythmus" do
    course = make_course(registration_mode: "single_session")
    date_a = Date.current.next_occurring(:friday)
    date_b = date_a + 7.days
    [ date_a, date_b ].each do |date|
      start_time = Time.zone.local(date.year, date.month, date.day, 18, 0)
      course.training_sessions.create!(start_time: start_time, end_time: start_time + 1.hour, is_canceled: false)
    end

    assert_equal "Freitag, 18:00–19:00", course_weekly_time(course)
  end

  test "category_locations liefert eindeutige, nicht-leere Orte" do
    a = make_course(title: "A")
    a.update_column(:location, "ewb-Halle")
    b = make_course(title: "B")
    b.update_column(:location, "Turnhalle Brunnmatt")
    c = make_course(title: "C")
    c.update_column(:location, "ewb-Halle")
    d = make_course(title: "D")
    d.update_column(:location, "")

    assert_equal [ "ewb-Halle", "Turnhalle Brunnmatt" ], category_locations([ a, b, c, d ])
  end

  test "course_weekday_index gibt Wochentag-Index der Session zurück" do
    course = make_course
    add_session(course, :monday, 17)

    assert_equal 1, course_weekday_index(course)
  end

  test "course_weekday_index ist nil bei Drop-In mit gemischten Wochentagen" do
    course = make_course(registration_mode: "single_session")
    add_session(course, :monday, 17)
    add_session(course, :thursday, 19)

    assert_nil course_weekday_index(course)
  end

  test "category_weekday_names liefert sortierte, eindeutige Namen (Montag zuerst)" do
    mon = make_course(title: "Mo")
    add_session(mon, :monday, 17)
    wed = make_course(title: "Mi")
    add_session(wed, :wednesday, 18)
    mon2 = make_course(title: "Mo2")
    add_session(mon2, :monday, 19)

    assert_equal [ "Montag", "Mittwoch" ], category_weekday_names([ wed, mon, mon2 ])
  end
end
