require "test_helper"

class WaitlistPromotionServiceTest < ActiveSupport::TestCase
  setup do
    @participant = participants(:parent_only_child)
  end

  test "promotes waitlisted registration to bestätigt for free course" do
    course = courses(:one)
    course.update!(max_participants: 1, enable_waitlist: true, has_payment: false, price_cents: 0)

    confirmed = CourseRegistration.create!(
      course: course, participant: participants(:one),
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false
    )

    waitlisted = CourseRegistration.create!(
      course: course, participant: @participant,
      status: "warteliste", payment_cleared: false, holiday_deduction_claimed: false
    )

    confirmed.destroy!

    assert_emails 1 do
      WaitlistPromotionService.promote_next_from_waitlist(course.reload)
    end

    assert_equal "bestätigt", waitlisted.reload.status
  end

  test "promotes waitlisted registration to ausstehend for paid course" do
    course = courses(:one)
    course.update!(max_participants: 1, enable_waitlist: true, has_payment: true, price_cents: 5000)

    confirmed = CourseRegistration.create!(
      course: course, participant: participants(:one),
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false
    )

    waitlisted = CourseRegistration.create!(
      course: course, participant: @participant,
      status: "warteliste", payment_cleared: false, holiday_deduction_claimed: false
    )

    confirmed.destroy!

    assert_emails 1 do
      WaitlistPromotionService.promote_next_from_waitlist(course.reload)
    end

    assert_equal "ausstehend", waitlisted.reload.status
  end

  test "does nothing when no waitlisted registrations exist" do
    course = courses(:one)
    course.update!(max_participants: 5, enable_waitlist: true, has_payment: false, price_cents: 0)

    assert_emails 0 do
      WaitlistPromotionService.promote_next_from_waitlist(course)
    end
  end

  test "does nothing when waitlist is not enabled" do
    course = courses(:one)
    course.update!(max_participants: 1, enable_waitlist: false, has_payment: false, price_cents: 0)

    CourseRegistration.create!(
      course: course, participant: @participant,
      status: "warteliste", payment_cleared: false, holiday_deduction_claimed: false
    )

    WaitlistPromotionService.promote_next_from_waitlist(course)

    assert_equal "warteliste", CourseRegistration.last.reload.status
  end
end
