require "test_helper"

class ExpireTrialRegistrationsJobTest < ActiveJob::TestCase
  def make_course
    course = Course.new(
      title: "Schnupper-Kurs", registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false, allows_trial: true
    )
    course.save!(validate: false)
    course
  end

  test "storniert Schnupper-Anmeldung mit trial_expires_at in der Vergangenheit" do
    course = make_course

    expired = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false,
      trial_expires_at: 1.day.ago
    )
    expired.save!(validate: false)

    ExpireTrialRegistrationsJob.new.perform

    assert_equal "storniert", expired.reload.status
  end

  test "lässt Schnupper-Anmeldung mit trial_expires_at in der Zukunft unberührt (trotz altem created_at)" do
    course = make_course

    valid_reg = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false,
      trial_expires_at: 5.days.from_now
    )
    valid_reg.save!(validate: false)
    valid_reg.update_column(:created_at, 30.days.ago)

    ExpireTrialRegistrationsJob.new.perform

    assert_equal "schnuppern", valid_reg.reload.status
  end

  test "storniert Altbestand ohne trial_expires_at anhand created_at" do
    course = make_course

    legacy = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    legacy.save!(validate: false)
    # Altbestand: keine Frist gesetzt, aber Anmeldung älter als 7 Tage
    legacy.update_columns(trial_expires_at: nil, created_at: 8.days.ago)

    ExpireTrialRegistrationsJob.new.perform

    assert_equal "storniert", legacy.reload.status
  end
end
