require "test_helper"

class RegistrationMoveServiceTest < ActiveSupport::TestCase
  setup do
    @participant = participants(:one)
    @from = build_course("KutuPlus", "KutuPlus", price_cents: 15000)
    @to   = build_course("KutuPlus Jr.", "KutuPlus Jr.", price_cents: 12000)
  end

  test "verschiebt kategorienübergreifend, resettet Session und rechnet Preis neu" do
    session = TrainingSession.new(course: @from,
      start_time: 1.week.from_now, end_time: 1.week.from_now + 1.hour, is_canceled: false)
    session.save!(validate: false)

    reg = CourseRegistration.new(course: @from, participant: @participant, status: "bestätigt",
      training_session_id: session.id, applied_price_cents: 15000,
      payment_cleared: true, holiday_deduction_claimed: false)
    reg.save!(validate: false)

    result = RegistrationMoveService.call(reg, @to, actor: users(:admin))

    assert result.moved
    reg.reload
    assert_equal @to.id, reg.course_id
    assert_nil reg.training_session_id
    assert_equal 12000, reg.applied_price_cents
    assert_equal "bestätigt", reg.status
    assert_equal(-3000, result.price_diff_cents)
  end

  test "voller Zielkurs setzt den Status auf warteliste" do
    @to.update_columns(max_participants: 0)

    reg = CourseRegistration.new(course: @from, participant: @participant, status: "bestätigt",
      payment_cleared: true, holiday_deduction_claimed: false)
    reg.save!(validate: false)

    result = RegistrationMoveService.call(reg, @to)

    assert result.moved
    assert_equal "warteliste", reg.reload.status
  end

  test "gleicher Kurs wird nicht verschoben" do
    reg = CourseRegistration.new(course: @from, participant: @participant, status: "bestätigt",
      holiday_deduction_claimed: false)
    reg.save!(validate: false)

    result = RegistrationMoveService.call(reg, @from)

    assert_not result.moved
    assert_equal :same_course, result.reason
    assert_equal @from.id, reg.reload.course_id
  end

  private

  def build_course(title, category, price_cents:)
    course = Course.new(title: title, category: category,
      registration_type: category, registration_mode: category,
      has_payment: true, has_ticketing: false, allows_holiday_deduction: false,
      price_cents: price_cents)
    course.save!(validate: false)
    course
  end
end
