require "test_helper"

class RefundServiceTest < ActiveSupport::TestCase
  def no_content_response
    r = Net::HTTPNoContent.new("1.1", "204", "No Content")
    r.instance_variable_set(:@body, "")
    r.instance_variable_set(:@read, true)
    r
  end

  def error_response(code, message, error_code = nil)
    r = Net::HTTPBadRequest.new("1.1", code.to_s, "Error")
    body = { "message" => message }
    body["error_code"] = error_code if error_code
    r.instance_variable_set(:@body, body.to_json)
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

  # Builds an unsaved registration with a course, bypassing DB
  def build_registration(attrs = {})
    course = Course.new(
      has_payment: true,
      price_cents: attrs.fetch(:price_cents, 10000),
      training_value_cents: attrs.fetch(:training_value_cents, 1500),
      title: "Test",
      registration_type: "semester"
    )

    reg = CourseRegistration.new(
      course: course,
      payment_cleared: attrs.fetch(:payment_cleared, true),
      sumup_transaction_id: attrs.fetch(:sumup_transaction_id, "txn_abc123"),
      status: "storniert",
      created_at: attrs.fetch(:created_at, 30.days.ago)
    )

    reg
  end

  # Stubs training_sessions scope to return a fixed count
  def stub_sessions_count(reg, count)
    scope = Object.new
    scope.define_singleton_method(:where) { |*_| scope }
    scope.define_singleton_method(:count) { count }
    reg.course.define_singleton_method(:training_sessions) { scope }
  end

  # ── Voraussetzungs-Guards ─────────────────────────────────────────────────

  test "no_payment when payment_cleared is false" do
    reg = build_registration(payment_cleared: false)
    result = RefundService.process(reg)
    assert_equal false, result[:refunded]
    assert_equal "no_payment", result[:reason]
  end

  test "no_payment when course has_payment is false" do
    reg = build_registration
    reg.course.has_payment = false
    result = RefundService.process(reg)
    assert_equal false, result[:refunded]
    assert_equal "no_payment", result[:reason]
  end

  test "no_transaction_id when sumup_transaction_id is blank" do
    reg = build_registration(sumup_transaction_id: nil)
    result = RefundService.process(reg)
    assert_equal false, result[:refunded]
    assert_equal "no_transaction_id", result[:reason]
  end

  test "no_training_value when training_value_cents is nil" do
    reg = build_registration(training_value_cents: nil)
    result = RefundService.process(reg)
    assert_equal false, result[:refunded]
    assert_equal "no_training_value", result[:reason]
  end

  test "no_training_value when training_value_cents is zero" do
    reg = build_registration(training_value_cents: 0)
    result = RefundService.process(reg)
    assert_equal false, result[:refunded]
    assert_equal "no_training_value", result[:reason]
  end

  # ── Abzugs-Logik ─────────────────────────────────────────────────────────

  test "no_amount_after_deduction when sessions cost equals price" do
    # price = 3000, 2 sessions * 1500 = 3000 → refund = 0
    reg = build_registration(price_cents: 3000, training_value_cents: 1500)
    stub_sessions_count(reg, 2)

    result = RefundService.process(reg)
    assert_equal false, result[:refunded]
    assert_equal "no_amount_after_deduction", result[:reason]
    assert_equal 2, result[:sessions_count]
    assert_equal 3000, result[:abzug_cents]
  end

  test "no_amount_after_deduction when deduction exceeds price" do
    # price = 3000, 3 sessions * 1500 = 4500 → refund = -1500
    reg = build_registration(price_cents: 3000, training_value_cents: 1500)
    stub_sessions_count(reg, 3)

    result = RefundService.process(reg)
    assert_equal false, result[:refunded]
    assert_equal "no_amount_after_deduction", result[:reason]
  end

  # ── Erfolgreicher Refund ──────────────────────────────────────────────────

  test "returns refunded true with full price when no sessions attended" do
    reg = build_registration(price_cents: 10000, training_value_cents: 1500)
    stub_sessions_count(reg, 0)

    with_http_stub(fake_http(no_content_response)) do
      result = RefundService.process(reg)
      assert_equal true, result[:refunded]
      assert_equal 10000, result[:amount_cents]
      assert_equal 0, result[:sessions_count]
    end
  end

  test "deducts sessions from refund amount" do
    # price = 10000, 2 sessions * 1500 = 3000 → refund = 7000
    reg = build_registration(price_cents: 10000, training_value_cents: 1500)
    stub_sessions_count(reg, 2)

    with_http_stub(fake_http(no_content_response)) do
      result = RefundService.process(reg)
      assert_equal true, result[:refunded]
      assert_equal 7000, result[:amount_cents]
      assert_equal 2, result[:sessions_count]
    end
  end

  # ── SumUp API Fehler ──────────────────────────────────────────────────────

  test "raises RuntimeError on SumUp API error response" do
    reg = build_registration(price_cents: 10000, training_value_cents: 1500)
    stub_sessions_count(reg, 0)

    with_http_stub(fake_http(error_response(400, "Transaction not refundable"))) do
      err = assert_raises(RuntimeError) { RefundService.process(reg) }
      assert_match "SumUp Refund API Fehler 400", err.message
      assert_match "Transaction not refundable", err.message
    end
  end

  test "error message includes a hint for insufficient balance" do
    reg = build_registration(price_cents: 10000, training_value_cents: 1500)
    stub_sessions_count(reg, 0)

    with_http_stub(fake_http(error_response(409, "Not enough balance to perform the operation", "NOT_ENOUGH_BALANCE"))) do
      err = assert_raises(RuntimeError) { RefundService.process(reg) }
      assert_match "Mögliche Ursache", err.message
      assert_match "Guthaben", err.message
      assert_match "SumUp Refund API Fehler 409", err.message
      assert_match "error_code: NOT_ENOUGH_BALANCE", err.message
    end
  end

  test "error message includes a hint for already refunded transaction" do
    reg = build_registration(price_cents: 10000, training_value_cents: 1500)
    stub_sessions_count(reg, 0)

    with_http_stub(fake_http(error_response(409, "Transaction already refunded", "TRANSACTION_ALREADY_REFUNDED"))) do
      err = assert_raises(RuntimeError) { RefundService.process(reg) }
      assert_match "bereits", err.message
    end
  end

  test "error message includes a generic not-refundable hint on 409" do
    reg = build_registration(price_cents: 10000, training_value_cents: 1500)
    stub_sessions_count(reg, 0)

    with_http_stub(fake_http(error_response(409, "The transaction is not refundable"))) do
      err = assert_raises(RuntimeError) { RefundService.process(reg) }
      assert_match "nicht erstattbar", err.message
      assert_match "SumUp Refund API Fehler 409", err.message
    end
  end

  test "error message includes a not-found hint on 404" do
    reg = build_registration(price_cents: 10000, training_value_cents: 1500)
    stub_sessions_count(reg, 0)

    with_http_stub(fake_http(error_response(404, "Resource not found", "NOT_FOUND"))) do
      err = assert_raises(RuntimeError) { RefundService.process(reg) }
      assert_match "nicht gefunden", err.message
    end
  end

  test "raises RuntimeError on network error" do
    reg = build_registration(price_cents: 10000, training_value_cents: 1500)
    stub_sessions_count(reg, 0)

    with_http_stub(fake_http_raising(SocketError.new("getaddrinfo: Name or service not known"))) do
      err = assert_raises(RuntimeError) { RefundService.process(reg) }
      assert_match "SumUp API nicht erreichbar", err.message
    end
  end

  test "raises RuntimeError on timeout" do
    reg = build_registration(price_cents: 10000, training_value_cents: 1500)
    stub_sessions_count(reg, 0)

    with_http_stub(fake_http_raising(Net::ReadTimeout.new)) do
      err = assert_raises(RuntimeError) { RefundService.process(reg) }
      assert_match "SumUp API nicht erreichbar", err.message
    end
  end
end
