require "test_helper"

class ManualEnrollmentReminderJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  def make_course(has_payment: true)
    course = Course.new(
      title: "Test Kurs", registration_type: "semester",
      has_payment: has_payment, price_cents: 15_000, has_ticketing: false, allows_holiday_deduction: false
    )
    course.save!(validate: false)
    course
  end

  def make_reg(course:, participant:, created_at:, payment_cleared: false, manually_enrolled: true)
    reg = CourseRegistration.new(
      course: course, participant: participant, status: "bestätigt",
      payment_cleared: payment_cleared, holiday_deduction_claimed: false,
      manually_enrolled: manually_enrolled
    )
    reg.save!(validate: false)
    reg.update_column(:created_at, created_at)
    reg
  end

  test "erinnert 7 Tage nach manueller Anmeldung, wenn Konto fehlt" do
    participant = participants(:two) # user :two hat family_data_completed: false
    reg = make_reg(course: make_course, participant: participant, created_at: 8.days.ago)

    assert_enqueued_emails 1 do
      ManualEnrollmentReminderJob.new.perform
    end
    assert reg.reload.manual_enrollment_reminder_sent_at.present?
  end

  test "erinnert 7 Tage nach manueller Anmeldung, wenn nicht bezahlt (Konto aber fertig)" do
    participant = participants(:parent_only_child) # user hat family_data_completed: true
    reg = make_reg(course: make_course, participant: participant, created_at: 8.days.ago)

    assert_enqueued_emails 1 do
      ManualEnrollmentReminderJob.new.perform
    end
    assert reg.reload.manual_enrollment_reminder_sent_at.present?
  end

  test "keine Erinnerung, wenn Konto fertig und bezahlt" do
    participant = participants(:parent_only_child)
    reg = make_reg(course: make_course, participant: participant, created_at: 8.days.ago, payment_cleared: true)

    assert_no_enqueued_emails do
      ManualEnrollmentReminderJob.new.perform
    end
    assert_nil reg.reload.manual_enrollment_reminder_sent_at
  end

  test "keine Erinnerung vor Ablauf der 7 Tage" do
    participant = participants(:two)
    reg = make_reg(course: make_course, participant: participant, created_at: 2.days.ago)

    assert_no_enqueued_emails do
      ManualEnrollmentReminderJob.new.perform
    end
    assert_nil reg.reload.manual_enrollment_reminder_sent_at
  end

  test "keine Erinnerung bei Selbstanmeldung (nicht manuell hinzugefügt)" do
    participant = participants(:two)
    reg = make_reg(course: make_course, participant: participant, created_at: 8.days.ago, manually_enrolled: false)

    assert_no_enqueued_emails do
      ManualEnrollmentReminderJob.new.perform
    end
    assert_nil reg.reload.manual_enrollment_reminder_sent_at
  end

  test "keine Erinnerung bei stornierter Anmeldung" do
    participant = participants(:two)
    reg = make_reg(course: make_course, participant: participant, created_at: 8.days.ago)
    reg.update_column(:status, "storniert")

    assert_no_enqueued_emails do
      ManualEnrollmentReminderJob.new.perform
    end
  end

  test "schickt Erinnerung nicht doppelt" do
    participant = participants(:two)
    reg = make_reg(course: make_course, participant: participant, created_at: 8.days.ago)
    reg.update_column(:manual_enrollment_reminder_sent_at, 1.day.ago)

    assert_no_enqueued_emails do
      ManualEnrollmentReminderJob.new.perform
    end
  end

  test "keine Erinnerung bei Gratiskurs, wenn nur die Zahlung fehlen würde" do
    participant = participants(:parent_only_child)
    reg = make_reg(course: make_course(has_payment: false), participant: participant, created_at: 8.days.ago)

    assert_no_enqueued_emails do
      ManualEnrollmentReminderJob.new.perform
    end
  end
end
