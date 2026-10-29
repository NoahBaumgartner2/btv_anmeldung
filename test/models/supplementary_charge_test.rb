require "test_helper"

class SupplementaryChargeTest < ActiveSupport::TestCase
  def make_course
    course = Course.new(title: "Nachforderungs-Kurs", registration_type: "semester",
      has_payment: true, has_ticketing: false, allows_holiday_deduction: false)
    course.price_cents = 15_000
    course.save!(validate: false)
    course
  end

  test "amount_display formatiert Rappen als CHF-Betrag" do
    charge = SupplementaryCharge.new(amount_cents: 3_000)
    assert_equal "CHF 30.00", charge.amount_display
  end

  test "status muss einer der definierten Werte sein" do
    charge = SupplementaryCharge.new(
      participant: participants(:one), course: make_course,
      amount_cents: 3_000, description: "Test", status: "irgendwas"
    )
    assert_not charge.valid?
    assert_includes charge.errors[:status], "ist kein gültiger Wert"
  end

  test "amount_cents muss positiv sein" do
    charge = SupplementaryCharge.new(
      participant: participants(:one), course: make_course,
      amount_cents: 0, description: "Test"
    )
    assert_not charge.valid?
  end

  test "description ist erforderlich" do
    charge = SupplementaryCharge.new(
      participant: participants(:one), course: make_course,
      amount_cents: 3_000, description: ""
    )
    assert_not charge.valid?
  end

  test "payable? und paid? spiegeln den Status" do
    charge = SupplementaryCharge.new(status: "offen")
    assert charge.payable?
    assert_not charge.paid?

    charge.status = "bezahlt"
    assert_not charge.payable?
    assert charge.paid?
  end

  test "sync_open markiert bei SumUp bezahlte Nachforderung als bezahlt (Fall Nilay Sümbül)" do
    paid = SupplementaryCharge.create!(participant: participants(:one), course: make_course,
      amount_cents: 3_000, description: "Test", sumup_checkout_id: "co-paid")
    pending = SupplementaryCharge.create!(participant: participants(:one), course: make_course,
      amount_cents: 3_000, description: "Test", sumup_checkout_id: "co-pending")

    bodies = {
      "co-paid"    => { status: "PAID", transactions: [ { id: "TX-9", timestamp: "2026-09-13T17:48:12Z" } ] },
      "co-pending" => { status: "PENDING" }
    }
    original = PaymentSyncService.method(:fetch_checkout)
    PaymentSyncService.define_singleton_method(:fetch_checkout) do |id|
      r = Net::HTTPOK.new("1.1", "200", "OK")
      r.instance_variable_set(:@body, bodies[id].to_json)
      r.instance_variable_set(:@read, true)
      r
    end
    begin
      SupplementaryCharge.sync_open
    ensure
      PaymentSyncService.singleton_class.send(:remove_method, :fetch_checkout)
      PaymentSyncService.define_singleton_method(:fetch_checkout, original)
    end

    assert paid.reload.paid?
    assert_equal "TX-9", paid.sumup_transaction_id
    assert_equal Time.utc(2026, 9, 13, 17, 48, 12), paid.paid_at
    assert pending.reload.payable?
  end

  test "status ist standardmässig offen" do
    charge = SupplementaryCharge.create!(
      participant: participants(:one), course: make_course,
      amount_cents: 3_000, description: "Test"
    )
    assert_equal "offen", charge.status
  end
end
