require "test_helper"

class ExpirePendingPaymentsJobTest < ActiveJob::TestCase
  def make_course
    course = Course.new(
      title: "Test Kurs", registration_type: "semester",
      has_payment: true, has_ticketing: false, allows_holiday_deduction: false
    )
    course.save!(validate: false)
    course
  end

  test "storniert abgelaufene ausstehende Anmeldungen" do
    course = make_course

    expired = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false,
      payment_expires_at: 1.hour.ago
    )
    expired.save!(validate: false)

    ExpirePendingPaymentsJob.new.perform

    assert_equal "storniert", expired.reload.status
  end

  test "lässt nicht-abgelaufene Anmeldungen unberührt" do
    course = make_course

    valid_reg = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false,
      payment_expires_at: 1.hour.from_now
    )
    valid_reg.save!(validate: false)

    ExpirePendingPaymentsJob.new.perform

    assert_equal "ausstehend", valid_reg.reload.status
  end

  test "lässt ausstehende Anmeldungen ohne payment_expires_at unberührt" do
    course = make_course

    stuck = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false,
      payment_expires_at: nil
    )
    stuck.save!(validate: false)

    # Job darf nil-payment_expires_at-Registrierungen nicht stornieren
    assert_nothing_raised { ExpirePendingPaymentsJob.new.perform }
    assert_equal "ausstehend", stuck.reload.status,
      "Anmeldungen ohne payment_expires_at dürfen nicht automatisch storniert werden"
  end

  test "ignoriert bereits bezahlte Anmeldungen" do
    course = make_course

    paid = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "ausstehend", payment_cleared: true, holiday_deduction_claimed: false,
      payment_expires_at: 1.hour.ago
    )
    paid.save!(validate: false)

    ExpirePendingPaymentsJob.new.perform

    assert_equal "ausstehend", paid.reload.status, "Bezahlte Anmeldung darf nicht storniert werden"
  end
end
