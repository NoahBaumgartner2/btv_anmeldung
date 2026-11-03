require "test_helper"

class AttendanceReminderJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    TrainingSession.update_all(attendance_confirmed_at: Time.current) # Fixtures ausblenden
    @course = Course.new(title: "Reminder Kurs", category: "Turnen", registration_type: "semester",
      registration_mode: "semester", has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    @course.save!(validate: false)
    @course.course_trainers.create!(trainer: trainers(:one))
    @session = @course.training_sessions.create!(start_time: 3.days.ago, end_time: 3.days.ago + 1.hour)
  end

  test "erinnert nicht bei einem Kurs ohne Teilnehmende" do
    assert_no_enqueued_emails { AttendanceReminderJob.perform_now }
    assert_nil @session.reload.trainer_reminded_at
  end

  test "erinnert bei einem Kurs mit Teilnehmenden" do
    CourseRegistration.new(course: @course, participant: participants(:one), status: "bestätigt",
      holiday_deduction_claimed: false).save!(validate: false)

    assert_enqueued_emails(1) { AttendanceReminderJob.perform_now }
    assert @session.reload.trainer_reminded_at.present?
  end
end
