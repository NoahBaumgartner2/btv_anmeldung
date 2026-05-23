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
end
