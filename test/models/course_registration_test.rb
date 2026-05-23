require "test_helper"

class CourseRegistrationTest < ActiveSupport::TestCase
  # ── Duplicate-registration validation ───────────────────────────────────────

  test "allows re-registration when existing registration is ausstehend" do
    # participants(:parent_only_child) has no existing registration in courses(:one)
    course       = courses(:one)
    participant  = participants(:parent_only_child)

    existing = CourseRegistration.new(
      course: course, participant: participant,
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false
    )
    existing.save!(validate: false)

    duplicate = CourseRegistration.new(
      course: course, participant: participant,
      payment_cleared: false, holiday_deduction_claimed: false
    )

    assert duplicate.valid?, "Expected no duplicate error for ausstehend registration, got: #{duplicate.errors.full_messages.join(', ')}"
  end

  test "blocks re-registration when existing registration is bestätigt" do
    # course_registrations(:one) already has participant :one in course :one with status "bestätigt"
    duplicate = CourseRegistration.new(
      course: courses(:one), participant: participants(:one),
      payment_cleared: false, holiday_deduction_claimed: false
    )

    assert_not duplicate.valid?
    assert_match I18n.t("course_registrations.errors.duplicate_registration"), duplicate.errors.full_messages.join
  end
end
