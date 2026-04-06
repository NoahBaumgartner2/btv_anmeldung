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
end
