require "test_helper"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @parent      = users(:parent_only)
    @participant = participants(:parent_only_child)

    @course = Course.new(title: "Bezahlkurs", registration_type: "semester",
      has_payment: true, has_ticketing: false, allows_holiday_deduction: false)
    @course.price_cents = 5000
    @course.save!(validate: false)

    @registration = CourseRegistration.new(course: @course, participant: @participant,
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false)
    @registration.save!(validate: false)

    sign_in @parent
  end

  # ── Stub-Helfer (analog zu PaymentSyncServiceTest) ───────────────────────────

  def stub_singleton_method(mod, name, value, &block)
    original = mod.method(name)
    mod.singleton_class.send(:remove_method, name)
    mod.define_singleton_method(name) { |*_args| value }
    block.call
  ensure
    mod.singleton_class.send(:remove_method, name)
    mod.define_singleton_method(name, original)
  end

  def with_sumup_configured(&block)
    stub_singleton_method(::SumupConfig, :configured?, true, &block)
  end

  def ok_response(body)
    r = Net::HTTPOK.new("1.1", "200", "OK")
    r.instance_variable_set(:@body, body)
    r.instance_variable_set(:@read, true)
    r
  end

  # ── checkout_preview ─────────────────────────────────────────────────────────

  test "bestätigt + unbezahlt + kostenpflichtig erreicht checkout_preview" do
    with_sumup_configured do
      get checkout_preview_registration_path(@registration)
      assert_response :success
    end
  end

  test "ausstehend + unbezahlt erreicht checkout_preview weiterhin" do
    @registration.update_columns(status: "ausstehend")

    with_sumup_configured do
      get checkout_preview_registration_path(@registration)
      assert_response :success
    end
  end

  test "bestätigt + bezahlt wird umgeleitet" do
    @registration.update_columns(payment_cleared: true)

    with_sumup_configured do
      get checkout_preview_registration_path(@registration)
      assert_redirected_to course_registration_path(@registration)
    end
  end

  test "storniert, warteliste und schnuppern werden umgeleitet" do
    with_sumup_configured do
      %w[storniert warteliste schnuppern].each do |status|
        @registration.update_columns(status: status)

        get checkout_preview_registration_path(@registration)
        assert_redirected_to course_registration_path(@registration),
          "Status #{status} darf keinen Checkout erreichen"
      end
    end
  end

  test "fremde Registration wird abgewiesen" do
    sign_in users(:two)

    with_sumup_configured do
      get checkout_preview_registration_path(@registration)
      assert_redirected_to root_path
    end
  end

  # ── success ──────────────────────────────────────────────────────────────────

  test "success lässt bestätigte Registration bestätigt – kein Warteliste-Downgrade" do
    # Kurs ist voll (anderer bestätigter Teilnehmer belegt den einzigen Platz laut
    # Kapazitätscheck) – der manuell zugesicherte Platz darf trotzdem bestehen bleiben.
    @course.update_columns(max_participants: 1)
    other = CourseRegistration.new(course: @course, participant: participants(:one),
      status: "bestätigt", payment_cleared: true, holiday_deduction_claimed: false)
    other.save!(validate: false)

    @registration.update_columns(sumup_checkout_id: "co-confirmed")
    paid_body = { status: "PAID", transactions: [ { id: "tx-confirmed" } ] }.to_json

    stub_singleton_method(PaymentSyncService, :fetch_checkout, ok_response(paid_body)) do
      get payments_success_path(checkout_id: "co-confirmed", registration_id: @registration.id)
    end

    @registration.reload
    assert @registration.payment_cleared?, "payment_cleared muss nach Zahlungseingang true sein"
    assert_equal "bestätigt", @registration.status,
      "Bereits bestätigte Anmeldung darf nicht auf die Warteliste downgegradet werden"
    assert_equal "tx-confirmed", @registration.sumup_transaction_id
  end

  test "success setzt ausstehende Registration bei vollem Kurs auf warteliste (bestehende Logik)" do
    @course.update_columns(max_participants: 1)
    other = CourseRegistration.new(course: @course, participant: participants(:one),
      status: "bestätigt", payment_cleared: true, holiday_deduction_claimed: false)
    other.save!(validate: false)

    @registration.update_columns(status: "ausstehend", sumup_checkout_id: "co-pending")
    paid_body = { status: "PAID", transactions: [ { id: "tx-pending" } ] }.to_json

    stub_singleton_method(PaymentSyncService, :fetch_checkout, ok_response(paid_body)) do
      get payments_success_path(checkout_id: "co-pending", registration_id: @registration.id)
    end

    @registration.reload
    assert @registration.payment_cleared?
    assert_equal "warteliste", @registration.status
  end
end
