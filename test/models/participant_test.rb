require "test_helper"

class ParticipantTest < ActiveSupport::TestCase
  setup do
    @participant = participants(:one)
    @course = Course.new(
      title: "Schnupper-Kurs",
      category: "Kids Gym",
      registration_type: "Kids Gym",
      registration_mode: "Kids Gym",
      has_payment: false,
      has_ticketing: false,
      allows_holiday_deduction: false
    )
    @course.save!(validate: false)
  end

  test "has_trialed_in_category? returns false when no trial registration exists" do
    assert_not @participant.has_trialed_in_category?("Kids Gym")
  end

  test "has_trialed_in_category? returns true when active trial exists within 7 days" do
    reg = CourseRegistration.new(
      course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)

    assert @participant.has_trialed_in_category?("Kids Gym")
  end

  test "has_trialed_in_category? returns false for different registration_type" do
    reg = CourseRegistration.new(
      course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)

    assert_not @participant.has_trialed_in_category?("Krabbel Gym")
  end

  test "has_trialed_in_category? returns false when trial is older than 7 days" do
    reg = CourseRegistration.new(
      course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)
    reg.update_column(:created_at, 8.days.ago)

    assert_not @participant.has_trialed_in_category?("Kids Gym")
  end

  test "ever_trialed_in_category? returns false when no trial exists" do
    assert_not @participant.ever_trialed_in_category?("Kids Gym")
  end

  test "ever_trialed_in_category? returns true for active trial" do
    reg = CourseRegistration.new(
      course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)

    assert @participant.ever_trialed_in_category?("Kids Gym")
  end

  test "ever_trialed_in_category? returns true even for expired trial" do
    reg = CourseRegistration.new(
      course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)
    reg.update_column(:created_at, 30.days.ago)

    assert @participant.ever_trialed_in_category?("Kids Gym")
  end

  test "ever_trialed_in_category? returns false for different category" do
    reg = CourseRegistration.new(
      course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)

    assert_not @participant.ever_trialed_in_category?("Krabbel Gym")
  end

  # ── schnupper_eligible_for_category? ──────────────────────────────────────

  test "schnupper_eligible_for_category? returns true when no registrations exist" do
    assert @participant.schnupper_eligible_for_category?("Kids Gym")
  end

  test "schnupper_eligible_for_category? returns false when already trialed" do
    reg = CourseRegistration.new(course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false)
    reg.save!(validate: false)
    assert_not @participant.schnupper_eligible_for_category?("Kids Gym")
  end

  test "schnupper_eligible_for_category? returns false when already confirmed in same category" do
    reg = CourseRegistration.new(course: @course, participant: @participant,
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false)
    reg.save!(validate: false)
    assert_not @participant.schnupper_eligible_for_category?("Kids Gym")
  end

  test "schnupper_eligible_for_category? returns false when previously confirmed but now cancelled" do
    reg = CourseRegistration.new(course: @course, participant: @participant,
      status: "storniert", payment_cleared: false, holiday_deduction_claimed: false)
    reg.save!(validate: false)
    assert_not @participant.schnupper_eligible_for_category?("Kids Gym")
  end

  # ── Identitäts-basierte Duplikat-Erkennung ────────────────────────────────

  test "ever_trialed_in_category? returns true when sibling with same AHV has trialed" do
    subject = Participant.new(
      user: users(:one), first_name: "Anna", last_name: "Muster",
      date_of_birth: Date.new(2012, 3, 15), gender: "w",
      phone_number: "0791000001", ahv_number: "756.9999.0001.11"
    ).tap { |p| p.save!(validate: false) }

    sibling = Participant.new(
      user: users(:two), first_name: "Anna", last_name: "Muster",
      date_of_birth: Date.new(2012, 3, 15), gender: "w",
      phone_number: "0791000002", ahv_number: "756.9999.0001.11"
    ).tap { |p| p.save!(validate: false) }

    CourseRegistration.new(course: @course, participant: sibling,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    ).tap { |r| r.save!(validate: false) }

    assert subject.ever_trialed_in_category?("Kids Gym")
  end

  test "ever_trialed_in_category? returns true when sibling with same name and DOB has trialed" do
    subject = Participant.new(
      user: users(:one), first_name: "Ben", last_name: "Beispiel",
      date_of_birth: Date.new(2013, 6, 20), gender: "m",
      phone_number: "0791000003", ahv_number: nil
    ).tap { |p| p.save!(validate: false) }

    sibling = Participant.new(
      user: users(:two), first_name: "Ben", last_name: "Beispiel",
      date_of_birth: Date.new(2013, 6, 20), gender: "m",
      phone_number: "0791000004", ahv_number: nil
    ).tap { |p| p.save!(validate: false) }

    CourseRegistration.new(course: @course, participant: sibling,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    ).tap { |r| r.save!(validate: false) }

    assert subject.ever_trialed_in_category?("Kids Gym")
  end

  test "ever_trialed_in_category? returns false when sibling has same name but different DOB" do
    subject = Participant.new(
      user: users(:one), first_name: "Clara", last_name: "Test",
      date_of_birth: Date.new(2011, 4, 10), gender: "w",
      phone_number: "0791000005", ahv_number: nil
    ).tap { |p| p.save!(validate: false) }

    other = Participant.new(
      user: users(:two), first_name: "Clara", last_name: "Test",
      date_of_birth: Date.new(2012, 4, 10), gender: "w",
      phone_number: "0791000006", ahv_number: nil
    ).tap { |p| p.save!(validate: false) }

    CourseRegistration.new(course: @course, participant: other,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    ).tap { |r| r.save!(validate: false) }

    assert_not subject.ever_trialed_in_category?("Kids Gym")
  end

  test "ever_trialed_in_category? returns false when other participant has different AHV" do
    subject = Participant.new(
      user: users(:one), first_name: "David", last_name: "Demo",
      date_of_birth: Date.new(2010, 1, 1), gender: "m",
      phone_number: "0791000007", ahv_number: "756.8888.0001.11"
    ).tap { |p| p.save!(validate: false) }

    other = Participant.new(
      user: users(:two), first_name: "David", last_name: "Demo",
      date_of_birth: Date.new(2010, 1, 1), gender: "m",
      phone_number: "0791000008", ahv_number: "756.8888.9999.99"
    ).tap { |p| p.save!(validate: false) }

    CourseRegistration.new(course: @course, participant: other,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    ).tap { |r| r.save!(validate: false) }

    assert_not subject.ever_trialed_in_category?("Kids Gym")
  end
end
