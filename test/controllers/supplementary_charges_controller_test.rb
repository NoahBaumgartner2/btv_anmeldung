require "test_helper"

class SupplementaryChargesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @parent      = users(:parent_only)
    @participant = participants(:parent_only_child)

    @course = Course.new(title: "Nachforderungs-Kurs", registration_type: "semester",
      has_payment: true, has_ticketing: false, allows_holiday_deduction: false)
    @course.price_cents = 15_000
    @course.save!(validate: false)

    @charge = SupplementaryCharge.create!(participant: @participant, course: @course,
      amount_cents: 3_000, description: "Korrektur Rabatt Q4 2026", explanation: "Warum auch immer.")

    sign_in @parent
  end

  def stub_singleton_method(mod, name, value, &block)
    original = mod.method(name)
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

  def fake_http(response)
    obj = Object.new
    obj.define_singleton_method(:use_ssl=) { |_| }
    obj.define_singleton_method(:open_timeout=) { |_| }
    obj.define_singleton_method(:read_timeout=) { |_| }
    obj.define_singleton_method(:request) { |_req| response }
    obj
  end

  test "show ist für Eigentümer erreichbar" do
    get supplementary_charge_path(@charge)
    assert_response :success
    assert_includes @response.body, "CHF 30.00"
    assert_includes @response.body, @charge.explanation
  end

  test "show ist für fremde Nutzer gesperrt" do
    sign_in users(:two)
    get supplementary_charge_path(@charge)
    assert_redirected_to root_path
  end

  test "show ist für Admin erreichbar" do
    sign_in users(:admin)
    get supplementary_charge_path(@charge)
    assert_response :success
  end

  test "checkout startet SumUp-Checkout und persistiert die checkout_id" do
    checkout_body = { id: "co-supcharge-1", hosted_checkout: { url: "https://pay.sumup.com/c/xyz" } }.to_json

    with_sumup_configured do
      stub_singleton_method(Net::HTTP, :new, fake_http(ok_response(checkout_body))) do
        get checkout_supplementary_charge_path(@charge)
      end
    end

    assert_redirected_to "https://pay.sumup.com/c/xyz"
    assert_equal "co-supcharge-1", @charge.reload.sumup_checkout_id
  end

  test "checkout bei bereits bezahlter Nachforderung leitet mit Hinweis um" do
    @charge.update!(status: "bezahlt", paid_at: Time.current)
    get checkout_supplementary_charge_path(@charge)
    assert_redirected_to supplementary_charge_path(@charge)
  end

  test "success markiert bezahlt und verschickt Quittung, wenn SumUp PAID meldet" do
    @charge.update!(sumup_checkout_id: "co-supcharge-2")
    paid_body = { status: "PAID", transactions: [ { id: "TX-1" } ] }.to_json

    assert_enqueued_emails 1 do
      stub_singleton_method(PaymentSyncService, :fetch_checkout, ok_response(paid_body)) do
        get success_supplementary_charge_path(@charge)
      end
    end

    @charge.reload
    assert @charge.paid?
    assert_equal "TX-1", @charge.sumup_transaction_id
    assert_redirected_to supplementary_charge_path(@charge)
    assert_equal "Deine Zahlung wurde erfolgreich verarbeitet.", flash[:notice]
  end
end
