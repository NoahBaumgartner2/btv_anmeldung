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

  test "status ist standardmässig offen" do
    charge = SupplementaryCharge.create!(
      participant: participants(:one), course: make_course,
      amount_cents: 3_000, description: "Test"
    )
    assert_equal "offen", charge.status
  end
end
