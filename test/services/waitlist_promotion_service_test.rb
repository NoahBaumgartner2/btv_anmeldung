require "test_helper"

class WaitlistPromotionServiceTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper

  def make_course(attrs = {})
    Course.new({
      title: "Waitlist Test Kurs", registration_type: "semester",
      has_payment: false, has_ticketing: false,
      allows_holiday_deduction: false, max_participants: 2,
      enable_waitlist: true, price_cents: 0
    }.merge(attrs)).tap { |c| c.save!(validate: false) }
  end

  test "promotes waitlisted registration to bestätigt for free course" do
    course = make_course(max_participants: 1, has_payment: false, price_cents: 0)

    confirmed = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false
    )
    confirmed.save!(validate: false)

    waitlisted = CourseRegistration.new(
      course: course, participant: participants(:two),
      status: "warteliste", payment_cleared: false, holiday_deduction_claimed: false
    )
    waitlisted.save!(validate: false)

    confirmed.destroy!

    assert_enqueued_emails 1 do
      WaitlistPromotionService.promote_next_from_waitlist(course.reload)
    end

    assert_equal "bestätigt", waitlisted.reload.status
  end

  test "promotes waitlisted registration to ausstehend for paid course" do
    course = make_course(max_participants: 1, has_payment: true, price_cents: 5000)

    confirmed = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false
    )
    confirmed.save!(validate: false)

    waitlisted = CourseRegistration.new(
      course: course, participant: participants(:two),
      status: "warteliste", payment_cleared: false, holiday_deduction_claimed: false
    )
    waitlisted.save!(validate: false)

    confirmed.destroy!

    assert_enqueued_emails 1 do
      WaitlistPromotionService.promote_next_from_waitlist(course.reload)
    end

    assert_equal "ausstehend", waitlisted.reload.status
  end

  test "does nothing when course is full (ausstehend occupies slot for paid course)" do
    course = make_course(max_participants: 1, has_payment: true, price_cents: 5000)

    pending_reg = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false
    )
    pending_reg.save!(validate: false)

    waitlisted = CourseRegistration.new(
      course: course, participant: participants(:two),
      status: "warteliste", payment_cleared: false, holiday_deduction_claimed: false
    )
    waitlisted.save!(validate: false)

    assert_enqueued_emails 0 do
      WaitlistPromotionService.promote_next_from_waitlist(course.reload)
    end

    assert_equal "warteliste", waitlisted.reload.status
  end

  test "does nothing when no waitlisted registrations exist" do
    course = make_course(max_participants: 5)

    assert_enqueued_emails 0 do
      WaitlistPromotionService.promote_next_from_waitlist(course)
    end
  end

  test "does nothing when waitlist is not enabled" do
    course = make_course(enable_waitlist: false, max_participants: 1)

    waitlisted = CourseRegistration.new(
      course: course, participant: participants(:parent_only_child),
      status: "warteliste", payment_cleared: false, holiday_deduction_claimed: false
    )
    waitlisted.save!(validate: false)

    WaitlistPromotionService.promote_next_from_waitlist(course)

    assert_equal "warteliste", waitlisted.reload.status
  end
end
