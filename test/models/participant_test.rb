require "test_helper"

class ParticipantTest < ActiveSupport::TestCase
  setup do
    @participant = participants(:one)
    @course = Course.new(
      title: "Schnupper-Kurs",
      registration_type: "semester",
      registration_mode: "semester",
      has_payment: false,
      has_ticketing: false,
      allows_holiday_deduction: false
    )
    @course.save!(validate: false)
  end

  test "has_trialed_in_category? returns false when no trial registration exists" do
    assert_not @participant.has_trialed_in_category?("semester")
  end

  test "has_trialed_in_category? returns true when active trial exists within 7 days" do
    reg = CourseRegistration.new(
      course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)

    assert @participant.has_trialed_in_category?("semester")
  end

  test "has_trialed_in_category? returns false for different registration_type" do
    reg = CourseRegistration.new(
      course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)

    assert_not @participant.has_trialed_in_category?("pro_training")
  end

  test "has_trialed_in_category? returns false when trial is older than 7 days" do
    reg = CourseRegistration.new(
      course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)
    reg.update_column(:created_at, 8.days.ago)

    assert_not @participant.has_trialed_in_category?("semester")
  end

  test "ever_trialed_in_category? returns false when no trial exists" do
    assert_not @participant.ever_trialed_in_category?("semester")
  end

  test "ever_trialed_in_category? returns true for active trial" do
    reg = CourseRegistration.new(
      course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)

    assert @participant.ever_trialed_in_category?("semester")
  end

  test "ever_trialed_in_category? returns true even for expired trial" do
    reg = CourseRegistration.new(
      course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)
    reg.update_column(:created_at, 30.days.ago)

    assert @participant.ever_trialed_in_category?("semester")
  end

  test "ever_trialed_in_category? returns false for different category" do
    reg = CourseRegistration.new(
      course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)

    assert_not @participant.ever_trialed_in_category?("pro_training")
  end
end
