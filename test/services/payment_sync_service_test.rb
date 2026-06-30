require "test_helper"

class PaymentSyncServiceTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  # ── HTTP-Stub-Helfer (analog zu InfomaniakNewsletterServiceTest) ────────────

  def ok_response(body = "{}")
    r = Net::HTTPOK.new("1.1", "200", "OK")
    r.instance_variable_set(:@body, body)
    r.instance_variable_set(:@read, true)
    r
  end

  def fake_http(response)
    obj = Object.new
    obj.define_singleton_method(:use_ssl=) { |_| }
    obj.define_singleton_method(:open_timeout=) { |_| }
    obj.define_singleton_method(:read_timeout=) { |_| }
    obj.define_singleton_method(:request) { |_req| response }
    obj
  end

  def fake_http_raising(error)
    obj = Object.new
    obj.define_singleton_method(:use_ssl=) { |_| }
    obj.define_singleton_method(:open_timeout=) { |_| }
    obj.define_singleton_method(:read_timeout=) { |_| }
    obj.define_singleton_method(:request) { |_req| raise error }
    obj
  end

  def with_http_stub(fake, &block)
    Net::HTTP.define_singleton_method(:new) { |*_| fake }
    block.call
  ensure
    Net::HTTP.singleton_class.send(:remove_method, :new)
  end

  # ── fetch_checkout – Netzwerkfehler ────────────────────────────────────────

  test "fetch_checkout wirft RuntimeError bei SocketError" do
    with_http_stub(fake_http_raising(SocketError.new("getaddrinfo failed"))) do
      error = assert_raises(RuntimeError) { PaymentSyncService.fetch_checkout("abc") }
      assert_includes error.message, "SumUp API nicht erreichbar"
    end
  end

  test "fetch_checkout wirft RuntimeError bei Net::ReadTimeout" do
    with_http_stub(fake_http_raising(Net::ReadTimeout.new)) do
      error = assert_raises(RuntimeError) { PaymentSyncService.fetch_checkout("abc") }
      assert_includes error.message, "SumUp API nicht erreichbar"
    end
  end

  test "fetch_checkout wirft RuntimeError bei Errno::ECONNREFUSED" do
    with_http_stub(fake_http_raising(Errno::ECONNREFUSED.new)) do
      error = assert_raises(RuntimeError) { PaymentSyncService.fetch_checkout("abc") }
      assert_includes error.message, "SumUp API nicht erreichbar"
    end
  end

  test "fetch_checkout gibt Response zurück bei Erfolg" do
    with_http_stub(fake_http(ok_response('{"status":"PAID"}'))) do
      response = PaymentSyncService.fetch_checkout("abc")
      assert_instance_of Net::HTTPOK, response
    end
  end

  # ── mark_paid! – Idempotenz ─────────────────────────────────────────────────

  test "mark_paid! markiert Registration als bezahlt und setzt Status bestätigt wenn Platz frei" do
    registration = course_registrations(:one)
    registration.update_columns(payment_cleared: false, status: "ausstehend")
    registration.course.update_columns(max_participants: 10)

    PaymentSyncService.mark_paid!(registration, transaction_id: "tx-123", checkout_id: "co-456")

    registration.reload
    assert registration.payment_cleared?
    assert_equal "tx-123", registration.sumup_transaction_id
    assert_equal "bestätigt", registration.status
  end

  test "mark_paid! wandelt Schnupperplatz nach Zahlung in bestätigt um" do
    course = Course.new(
      title: "Schnupper-Zahlkurs", registration_type: "semester", has_payment: true,
      price_cents: 10_000, has_ticketing: false, allows_holiday_deduction: false, max_participants: 10
    )
    course.save!(validate: false)

    trial = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    trial.save!(validate: false)

    PaymentSyncService.mark_paid!(trial, transaction_id: "tx-trial", checkout_id: "co-trial")

    trial.reload
    assert trial.payment_cleared?
    assert_equal "bestätigt", trial.status
  end

  test "mark_paid! überspringt bereits bezahlte Registration" do
    registration = course_registrations(:one)
    registration.update_columns(payment_cleared: true, status: "bestätigt", sumup_transaction_id: "orig-tx")

    PaymentSyncService.mark_paid!(registration, transaction_id: "new-tx")

    registration.reload
    assert_equal "orig-tx", registration.sumup_transaction_id, "Bereits bezahlte Registration darf nicht überschrieben werden"
  end

  test "mark_paid! setzt bestätigt auch wenn andere Teilnehmer ausstehend sind" do
    course = Course.new(
      title: "Kurs mit ausstehenden", registration_type: "semester", has_payment: true,
      has_ticketing: false, allows_holiday_deduction: false, max_participants: 2
    )
    course.save!(validate: false)

    # participant_a hat ausstehende Anmeldung (nicht bestätigt → zählt nicht als belegt)
    pending_a = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false
    )
    pending_a.save!(validate: false)

    # participant_b bezahlt jetzt → soll bestätigt werden, nicht warteliste
    pending_b = CourseRegistration.new(
      course: course, participant: participants(:two),
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false
    )
    pending_b.save!(validate: false)

    PaymentSyncService.mark_paid!(pending_b, transaction_id: "tx-ok")

    pending_b.reload
    assert pending_b.payment_cleared?
    assert_equal "bestätigt", pending_b.status,
      "Ausstehende Anmeldungen anderer Teilnehmer dürfen nicht als belegt zählen"
  end

  test "mark_paid! bestätigt eine bezahlte Anmeldung auch bei vollem Kurs (Überbuchung statt Warteliste)" do
    course = Course.new(
      title: "Voller Kurs", registration_type: "semester", has_payment: true,
      has_ticketing: false, allows_holiday_deduction: false, max_participants: 1
    )
    course.save!(validate: false)

    participant_a = participants(:one)
    participant_b = participants(:two)

    # Platz 1 bereits bestätigt belegt
    confirmed = CourseRegistration.new(
      course: course, participant: participant_a,
      status: "bestätigt", payment_cleared: true, holiday_deduction_claimed: false
    )
    confirmed.save!(validate: false)

    # Neue ausstehende Anmeldung – Kurs füllte sich während des offenen Checkouts
    pending = CourseRegistration.new(
      course: course, participant: participant_b,
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false
    )
    pending.save!(validate: false)

    PaymentSyncService.mark_paid!(pending, transaction_id: "tx-overbook")

    pending.reload
    assert pending.payment_cleared?
    assert_equal "bestätigt", pending.status,
      "Wer bezahlt hat, darf nie auf die Warteliste gesetzt werden – im vollen Kurs wird überbucht"
  end

  test "mark_paid! verschickt bei vollem Kurs KEINE Warteliste-Mail – Status bleibt bestätigt" do
    course = Course.new(
      title: "Voller Zahlkurs", registration_type: "semester", has_payment: true,
      price_cents: 18_000, has_ticketing: false, allows_holiday_deduction: false, max_participants: 1
    )
    course.save!(validate: false)

    CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "bestätigt", payment_cleared: true, holiday_deduction_claimed: false
    ).save!(validate: false)

    pending = CourseRegistration.new(
      course: course, participant: participants(:two),
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false
    )
    pending.save!(validate: false)

    assert_enqueued_emails 2 do
      PaymentSyncService.mark_paid!(pending, transaction_id: "tx-full")
    end

    pending.reload
    assert_equal "bestätigt", pending.status
    # confirmation rendert bei Status "bestätigt" die Bestätigungs-Mail (kein Warteliste-Wortlaut)
    assert_enqueued_email_with CourseRegistrationMailer, :confirmation, args: [ pending ]
    assert_enqueued_email_with CourseRegistrationMailer, :payment_receipt, args: [ pending ]
  end

  # ── mark_paid! – Mailversand ────────────────────────────────────────────────

  test "mark_paid! verschickt Bestätigung UND Quittung genau einmal" do
    registration = course_registrations(:one)
    registration.update_columns(payment_cleared: false, status: "ausstehend")
    registration.course.update_columns(max_participants: 10)

    assert_enqueued_emails 2 do
      PaymentSyncService.mark_paid!(registration, transaction_id: "tx-1", checkout_id: "co-1")
    end

    assert_enqueued_email_with CourseRegistrationMailer, :confirmation, args: [ registration ]
    assert_enqueued_email_with CourseRegistrationMailer, :payment_receipt, args: [ registration ]
  end

  test "zweiter mark_paid!-Aufruf verschickt keine weiteren Mails" do
    registration = course_registrations(:one)
    registration.update_columns(payment_cleared: true, status: "bestätigt")

    assert_no_enqueued_emails do
      PaymentSyncService.mark_paid!(registration, transaction_id: "tx-2")
    end
  end

  # ── sync_pending – Schnupperplatz mit gestartetem Checkout ──────────────────

  test "sync_pending gleicht Schnupperplatz mit Checkout-ID ab und bestätigt bei PAID" do
    course = Course.new(
      title: "Schnupper-Sync-Kurs", registration_type: "semester", has_payment: true,
      price_cents: 10_000, has_ticketing: false, allows_holiday_deduction: false, max_participants: 10
    )
    course.save!(validate: false)

    trial = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false,
      sumup_checkout_id: "co-trial-sync"
    )
    trial.save!(validate: false)

    with_http_stub(fake_http(ok_response('{"id":"co-trial-sync","status":"PAID","transactions":[{"id":"tx-sync"}]}'))) do
      result = PaymentSyncService.sync_pending
      assert_equal 1, result.paid
    end

    trial.reload
    assert trial.payment_cleared?
    assert_equal "bestätigt", trial.status
  end
end
