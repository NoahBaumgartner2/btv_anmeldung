require "test_helper"

class PaymentSyncServiceTest < ActiveSupport::TestCase
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
    obj.define_singleton_method(:request) { |_req| response }
    obj
  end

  def fake_http_raising(error)
    obj = Object.new
    obj.define_singleton_method(:use_ssl=) { |_| }
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

  test "mark_paid! markiert Registration als bezahlt" do
    registration = course_registrations(:one)
    registration.update_columns(payment_cleared: false, status: "ausstehend")

    PaymentSyncService.mark_paid!(registration, transaction_id: "tx-123", checkout_id: "co-456")

    registration.reload
    assert registration.payment_cleared?
    assert_equal "tx-123", registration.sumup_transaction_id
  end

  test "mark_paid! überspringt bereits bezahlte Registration" do
    registration = course_registrations(:one)
    registration.update_columns(payment_cleared: true, status: "bestätigt", sumup_transaction_id: "orig-tx")

    PaymentSyncService.mark_paid!(registration, transaction_id: "new-tx")

    registration.reload
    assert_equal "orig-tx", registration.sumup_transaction_id, "Bereits bezahlte Registration darf nicht überschrieben werden"
  end
end
