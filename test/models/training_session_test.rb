require "test_helper"

class TrainingSessionTest < ActiveSupport::TestCase
  setup do
    @session = training_sessions(:one)
    @session.attendances.destroy_all
  end

  # --- attendance_recorded? ---

  test "attendance_recorded? returns false when no attendances exist" do
    assert_not @session.attendance_recorded?
  end

  test "attendance_recorded? returns false when all attendances are abgemeldet" do
    @session.attendances.create!(course_registration: course_registrations(:one), status: "abgemeldet")
    assert_not @session.attendance_recorded?
  end

  test "attendance_recorded? returns true when at least one attendance is anwesend" do
    @session.attendances.create!(course_registration: course_registrations(:one), status: "anwesend")
    assert @session.attendance_recorded?
  end

  test "attendance_recorded? returns true when at least one attendance is abwesend" do
    @session.attendances.create!(course_registration: course_registrations(:one), status: "abwesend")
    assert @session.attendance_recorded?
  end

  test "attendance_recorded? returns true when mix of abgemeldet and anwesend exists" do
    @session.attendances.create!(course_registration: course_registrations(:one), status: "abgemeldet")
    @session.attendances.create!(course_registration: course_registrations(:two), status: "anwesend")
    assert @session.attendance_recorded?
  end

  test "attendance_recorded? returns true for canceled session regardless of attendances" do
    @session.update!(is_canceled: true)
    assert @session.attendance_recorded?
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
end
