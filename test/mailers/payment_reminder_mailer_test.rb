require "test_helper"

class PaymentReminderMailerTest < ActionMailer::TestCase
  # Regression: die Mail zeigte bisher immer den vollen Kurspreis
  # (course.price_display), unabhängig von einem greifenden Geschwister-/
  # Zweitkursrabatt - Familien mit zwei Kursen wurden dadurch fälschlich zur
  # Zahlung des vollen Betrags aufgefordert (Bug-Report Familie Stauffer).
  test "reminder zeigt den rabattierten Preis, nicht den vollen Kurspreis" do
    course_a = Course.new(title: "Kurs A", registration_type: "semester", category: "polysport",
      has_payment: true, has_ticketing: false, allows_holiday_deduction: false,
      discounts_enabled: true, price_cents: 15_000, second_course_price_cents: 12_000)
    course_a.save!(validate: false)
    course_b = Course.new(title: "Kurs B", registration_type: "semester", category: "polysport",
      has_payment: true, has_ticketing: false, allows_holiday_deduction: false,
      discounts_enabled: true, price_cents: 15_000, second_course_price_cents: 12_000)
    course_b.save!(validate: false)

    child = participants(:one)
    first_reg = CourseRegistration.new(course: course_a, participant: child, status: "bestätigt",
      payment_cleared: false, holiday_deduction_claimed: false)
    first_reg.save!(validate: false)
    second_reg = CourseRegistration.new(course: course_b, participant: child, status: "bestätigt",
      payment_cleared: false, holiday_deduction_claimed: false)
    second_reg.save!(validate: false)

    mail = PaymentReminderMailer.reminder(second_reg)

    assert_match "CHF 120.00", mail.body.encoded
    assert_no_match "CHF 150.00", mail.body.encoded
  end
end
