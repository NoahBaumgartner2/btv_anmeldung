require "test_helper"

class ParticipantAttendanceHistoryTest < ActiveSupport::TestCase
  setup do
    @participant = participants(:one)
    @course = build_course("Kunstturnen")
    @registration = register(@course, "bestätigt", created_at: 3.months.ago)
  end

  test "leitet den Status jedes Trainings aus Eintrag und Bestätigung ab" do
    confirmed = session_at(@course, 5.weeks.ago, confirmed: true)
    absent = session_at(@course, 4.weeks.ago, confirmed: true)
    excused = session_at(@course, 3.weeks.ago)
    personal = session_at(@course, 2.weeks.ago)
    open = session_at(@course, 1.week.ago)
    called_off = session_at(@course, 3.days.ago, is_canceled: true, cancellation_reason: "Halle zu")
    future = session_at(@course, 1.week.from_now)

    absent.attendances.create!(course_registration: @registration, status: "abwesend")
    excused.attendances.create!(course_registration: @registration, status: "abgemeldet")
    personal.attendances.create!(course_registration: @registration, status: "abgemeldet", cancellation_reason: "Trainer krank")

    entry = entry_for(@course)
    statuses = entry.rows.to_h { |row| [ row.session.id, row.status ] }

    assert_equal :present, statuses[confirmed.id]
    assert_equal :absent, statuses[absent.id]
    assert_equal :excused, statuses[excused.id]
    assert_equal :cancelled, statuses[personal.id]
    assert_equal :unrecorded, statuses[open.id]
    assert_equal :cancelled, statuses[called_off.id]
    assert_equal :planned, statuses[future.id]
    assert_equal "Halle zu", entry.rows.find { |row| row.session == called_off }.reason
    assert_equal "Trainer krank", entry.rows.find { |row| row.session == personal }.reason
    assert_equal 3, entry.recorded_count
  end

  test "Drop-in: bestätigtes Training ohne Eintrag gilt als abwesend" do
    @course.update_columns(has_ticketing: true)
    session = session_at(@course, 1.week.ago, confirmed: true)
    @registration.update_columns(training_session_id: session.id)

    assert_equal [ :absent ], entry_for(@course).rows.map(&:status)
  end

  test "Trainings vor der Anmeldung zählen nicht" do
    @registration.update_columns(created_at: 2.weeks.ago, enrolled_at: 2.weeks.ago)
    session_at(@course, 1.month.ago, confirmed: true)
    later = session_at(@course, 1.week.ago, confirmed: true)

    assert_equal [ later.id ], entry_for(@course).rows.map { |row| row.session.id }
  end

  test "stornierte Anmeldung zeigt nur Einträge, Warteliste keine Trainings" do
    @registration.update_columns(status: "storniert")
    recorded = session_at(@course, 2.weeks.ago, confirmed: true)
    session_at(@course, 1.week.ago, confirmed: true)
    recorded.attendances.create!(course_registration: @registration, status: "anwesend")
    waitlisted = build_course("Trampolin")
    register(waitlisted, "warteliste")
    session_at(waitlisted, 1.week.ago, confirmed: true)

    entries = history.index_by(&:course)
    assert_equal [ recorded.id ], entries[@course].rows.map { |row| row.session.id }
    assert_empty entries[waitlisted].rows
    assert_equal "warteliste", entries[waitlisted].registration.status
  end

  test "nach dem Verschieben bleibt der alte Kurs mit seinen Einträgen sichtbar" do
    old_session = session_at(@course, 2.weeks.ago, confirmed: true)
    target = build_course("Trampolin")

    RegistrationMoveService.call(@registration, target)

    entries = history.index_by(&:course)
    assert_equal [ :present ], entries[@course].rows.map(&:status)
    assert_equal old_session.id, entries[@course].rows.first.session.id
    assert_nil entries[@course].registration
    assert_equal target, entries[@course].moved_to
    assert_equal 1, entries[target].sessions_before_move
  end

  test "laufende Kurse sind aktiv, beendete, stornierte und verschobene gehören ins Archiv" do
    assert entry_for(@course).active?, "laufender Kurs"
    waiting = build_course("Warteliste")
    register(waiting, "warteliste")
    assert entry_for(waiting).active?, "Warteliste läuft noch"

    ended = build_course("Beendet")
    ended.update_columns(end_date: 1.day.ago)
    register(ended, "bestätigt")
    assert_not entry_for(ended).active?

    deactivated = build_course("Deaktiviert")
    register(deactivated, "bestätigt")
    deactivated.update_columns(deactivated_at: 1.day.ago)
    assert_not entry_for(deactivated).active?

    cancelled = build_course("Storniert")
    register(cancelled, "storniert")
    assert_not entry_for(cancelled).active?

    session_at(@course, 1.week.ago, confirmed: true)
    RegistrationMoveService.call(@registration, build_course("Ziel"))
    assert_not entry_for(@course).active?, "verschoben"
  end

  private

  def history = ParticipantAttendanceHistory.call(@participant.reload)

  def entry_for(course) = history.find { |entry| entry.course == course }

  def build_course(title)
    course = Course.new(title: title, category: title, registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    course.save!(validate: false)
    course
  end

  def register(course, status, **attrs)
    registration = CourseRegistration.new(course: course, participant: @participant, status: status,
      payment_cleared: false, holiday_deduction_claimed: false, **attrs)
    registration.save!(validate: false)
    registration.update_columns(enrolled_at: registration.created_at)
    registration
  end

  def session_at(course, time, confirmed: false, **attrs)
    session = TrainingSession.new(course: course, start_time: time, end_time: time + 1.hour,
      attendance_confirmed_at: (time if confirmed), **attrs)
    session.save!(validate: false)
    session
  end
end
