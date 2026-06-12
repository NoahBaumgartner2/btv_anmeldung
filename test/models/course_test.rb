require "test_helper"

class CourseTest < ActiveSupport::TestCase
  def base_attrs
    {
      title: "Test Kurs",
      registration_type: "semester",
      registration_mode: "semester",
      has_payment: false,
      has_ticketing: false,
      allows_holiday_deduction: false
    }
  end

  test "allows_trial is valid regardless of requires_ahv_number" do
    course = Course.new(base_attrs.merge(allows_trial: true, requires_ahv_number: false))
    assert course.valid?, course.errors.full_messages.inspect
  end

  test "allows_trial false is valid regardless of requires_ahv_number" do
    course = Course.new(base_attrs.merge(allows_trial: false, requires_ahv_number: false))
    assert course.valid?, course.errors.full_messages.inspect
  end

  test "allows_trial defaults to false" do
    course = Course.new(base_attrs)
    assert_equal false, course.allows_trial
  end

  # ── Preisreduktion ───────────────────────────────────────────────────────────

  def paid_attrs
    base_attrs.merge(has_payment: true, price_cents: 10_000)
  end

  test "discounts_enabled ohne Beträge ist ungültig" do
    course = Course.new(paid_attrs.merge(discounts_enabled: true))
    assert_not course.valid?
    assert course.errors[:base].any?
  end

  test "discounts_enabled mit einem gesetzten Betrag ist gültig" do
    course = Course.new(paid_attrs.merge(discounts_enabled: true, sibling_price_cents: 6_000))
    assert course.valid?, course.errors.full_messages.inspect
  end

  test "Rabattpreis gleich oder über Kurspreis ist ungültig" do
    course = Course.new(paid_attrs.merge(discounts_enabled: true, sibling_price_cents: 10_000))
    assert_not course.valid?
    assert course.errors[:sibling_price_cents].any?
  end

  test "negativer Rabattpreis ist ungültig" do
    course = Course.new(paid_attrs.merge(discounts_enabled: true, second_course_price_cents: -100))
    assert_not course.valid?
    assert course.errors[:second_course_price_cents].any?
  end

  test "ohne discounts_enabled werden Rabattfelder nicht validiert" do
    course = Course.new(paid_attrs.merge(discounts_enabled: false, sibling_price_cents: 99_000))
    assert course.valid?, course.errors.full_messages.inspect
  end

  test "sibling_price_chf konvertiert CHF in Cents und zurück" do
    course = Course.new(paid_attrs)
    course.sibling_price_chf = "60.50"
    assert_equal 6_050, course.sibling_price_cents
    assert_equal "60.50", course.sibling_price_chf
    assert_equal "CHF 60.50", course.sibling_price_display
  end
end
