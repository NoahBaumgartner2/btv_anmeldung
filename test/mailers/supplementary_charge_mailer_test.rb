require "test_helper"

class SupplementaryChargeMailerTest < ActionMailer::TestCase
  def make_charge(attrs = {})
    course = Course.new(title: "Nachforderungs-Kurs", registration_type: "semester",
      has_payment: true, has_ticketing: false, allows_holiday_deduction: false)
    course.price_cents = 15_000
    course.save!(validate: false)

    SupplementaryCharge.create!({
      participant: participants(:one),
      course:      course,
      amount_cents: 3_000,
      description: "Korrektur Rabatt Q4 2026"
    }.merge(attrs))
  end

  test "request enthält Betrag, Zahlungslink und Erklärtext" do
    charge = make_charge(explanation: "Es wurde fälschlich ein Geschwisterrabatt angewendet.")
    mail = SupplementaryChargeMailer.payment_request(charge)

    assert_match "CHF 30.00", mail.subject
    assert_match "CHF 30.00", mail.html_part.body.to_s
    assert_match "Es wurde fälschlich ein Geschwisterrabatt angewendet.", mail.html_part.body.to_s
    assert_match Rails.application.routes.url_helpers.supplementary_charge_url(charge, host: "example.com"), mail.html_part.body.to_s
    assert_equal [ participants(:one).user.email ], mail.to
  end

  test "request wird nicht verschickt, wenn Benachrichtigung deaktiviert ist" do
    MailSetting.current.set_notification_enabled!("supplementary_charge_request", false)
    charge = make_charge
    mail = SupplementaryChargeMailer.payment_request(charge)
    assert_nil mail.to
  end

  test "receipt enthält Betrag, Beschreibung und Zahlungsdatum" do
    charge = make_charge(status: "bezahlt", paid_at: Time.current, sumup_transaction_id: "TX-42")
    mail = SupplementaryChargeMailer.receipt(charge)

    assert_match "Korrektur Rabatt Q4 2026", mail.subject
    assert_match "CHF 30.00", mail.html_part.body.to_s
    assert_match "TX-42", mail.html_part.body.to_s
    assert_equal [ participants(:one).user.email ], mail.to
  end
end
