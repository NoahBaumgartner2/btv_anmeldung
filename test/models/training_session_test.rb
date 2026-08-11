require "test_helper"

class TrainingSessionTest < ActiveSupport::TestCase
  setup do
    @session = training_sessions(:one)
    @session.attendances.destroy_all
  end

  # --- attendance_recorded? (jetzt bestätigungsbasiert) ---

  test "attendance_recorded? returns false when not confirmed" do
    @session.update!(attendance_confirmed_at: nil)
    assert_not @session.attendance_recorded?
  end

  test "attendance_recorded? returns false even when attendances exist but not confirmed" do
    @session.attendances.create!(course_registration: course_registrations(:one), status: "anwesend")
    @session.update!(attendance_confirmed_at: nil)
    assert_not @session.attendance_recorded?
  end

  test "attendance_recorded? returns true when confirmed even without attendances" do
    @session.update!(attendance_confirmed_at: Time.current)
    assert @session.attendance_recorded?
  end

  test "attendance_recorded? returns true for canceled session regardless of confirmation" do
    @session.update!(is_canceled: true, attendance_confirmed_at: nil)
    assert @session.attendance_recorded?
  end

  # --- attendance_confirmed? / confirm_attendance! / reopen_attendance! ---

  test "confirm_attendance! sets confirmed_at and confirmed_by, works with 0 attendances" do
    @session.update!(attendance_confirmed_at: nil)
    @session.confirm_attendance!(users(:admin))

    assert @session.attendance_confirmed?
    assert_equal users(:admin), @session.attendance_confirmed_by
    assert_not_nil @session.attendance_confirmed_at
  end

  test "reopen_attendance! clears confirmation" do
    @session.confirm_attendance!(users(:admin))
    @session.reopen_attendance!

    assert_not @session.attendance_confirmed?
    assert_nil @session.attendance_confirmed_at
    assert_nil @session.attendance_confirmed_by
  end

  # --- needs_trainer_reminder? ---

  test "needs_trainer_reminder? returns false when end_time is less than 24 hours ago" do
    @session.update!(end_time: 23.hours.ago, trainer_reminded_at: nil)
    assert_not @session.needs_trainer_reminder?
  end

  test "needs_trainer_reminder? returns true when end_time is more than 24 hours ago and not yet reminded" do
    @session.update!(end_time: 25.hours.ago, trainer_reminded_at: nil)
    assert @session.needs_trainer_reminder?
  end

  test "needs_trainer_reminder? returns false when already reminded" do
    @session.update!(end_time: 25.hours.ago, trainer_reminded_at: Time.current)
    assert_not @session.needs_trainer_reminder?
  end

  # --- needs_admin_notification? ---

  test "needs_admin_notification? returns false when end_time is less than 7 days ago" do
    @session.update!(end_time: 6.days.ago, admin_notified_at: nil)
    assert_not @session.needs_admin_notification?
  end

  test "needs_admin_notification? returns true when end_time is more than 7 days ago and not yet notified" do
    @session.update!(end_time: 8.days.ago, admin_notified_at: nil)
    assert @session.needs_admin_notification?
  end

  test "needs_admin_notification? returns false when already notified" do
    @session.update!(end_time: 8.days.ago, admin_notified_at: Time.current)
    assert_not @session.needs_admin_notification?
  end

  # --- attending_count ---

  test "attending_count zaehlt abgemeldete Teilnehmer nicht mit" do
    course = Course.new(title: "Attending-Count-Kurs", registration_mode: "single_session",
                         start_date: Date.today, end_date: 1.year.from_now.to_date, registration_type: "kurs")
    course.save!(validate: false)
    session = course.training_sessions.create!(
      start_time: 1.day.from_now, end_time: 1.day.from_now + 1.hour, is_canceled: false
    )

    reg_a = CourseRegistration.new(course: course, participant: participants(:one), status: "bestätigt")
    reg_a.save!(validate: false)
    reg_b = CourseRegistration.new(course: course, participant: participants(:two), status: "bestätigt")
    reg_b.save!(validate: false)

    assert_equal 2, session.attending_count

    session.attendances.create!(course_registration: reg_a, status: "abgemeldet")

    assert_equal 1, session.reload.attending_count
  end
end
