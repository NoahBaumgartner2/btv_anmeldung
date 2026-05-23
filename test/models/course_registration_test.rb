require "test_helper"

class CourseRegistrationTest < ActiveSupport::TestCase
  # ── DB-level unique index ────────────────────────────────────────────────────

  test "DB-Constraint verhindert doppelte aktive Anmeldung" do
    course = Course.new(title: "X", registration_type: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    course.save!(validate: false)

    participant = participants(:one)

    first = CourseRegistration.new(course: course, participant: participant,
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false)
    first.save!(validate: false)

    second = CourseRegistration.new(course: course, participant: participant,
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false)

    assert_raises(ActiveRecord::RecordNotUnique) do
      second.save!(validate: false)
    end
  end

  test "DB-Constraint erlaubt mehrere aktive Single-Session-Anmeldungen für verschiedene Sessions" do
    course = Course.new(title: "Single Session X", registration_type: "single_session",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    course.save!(validate: false)

    session_one = TrainingSession.new(course: course)
    session_one.save!(validate: false)

    session_two = TrainingSession.new(course: course)
    session_two.save!(validate: false)

    participant = participants(:one)

    first = CourseRegistration.new(course: course, participant: participant,
      training_session: session_one, status: "bestätigt",
      payment_cleared: false, holiday_deduction_claimed: false)
    first.save!(validate: false)

    second = CourseRegistration.new(course: course, participant: participant,
      training_session: session_two, status: "bestätigt",
      payment_cleared: false, holiday_deduction_claimed: false)

    assert second.save(validate: false),
      "Mehrere aktive Single-Session-Anmeldungen für unterschiedliche Sessions sollen möglich sein"
  end

  test "DB-Constraint verhindert doppelte aktive Single-Session-Anmeldung in derselben Session" do
    course = Course.new(title: "Single Session Y", registration_type: "single_session",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    course.save!(validate: false)

    session = TrainingSession.new(course: course)
    session.save!(validate: false)

    participant = participants(:one)

    first = CourseRegistration.new(course: course, participant: participant,
      training_session: session, status: "bestätigt",
      payment_cleared: false, holiday_deduction_claimed: false)
    first.save!(validate: false)

    second = CourseRegistration.new(course: course, participant: participant,
      training_session: session, status: "bestätigt",
      payment_cleared: false, holiday_deduction_claimed: false)

    assert_raises(ActiveRecord::RecordNotUnique) do
      second.save!(validate: false)
    end
  end

  test "stornierte Anmeldung erlaubt Neu-Anmeldung" do
    course = Course.new(title: "Y", registration_type: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    course.save!(validate: false)

    participant = participants(:one)

    cancelled = CourseRegistration.new(course: course, participant: participant,
      status: "storniert", payment_cleared: false, holiday_deduction_claimed: false)
    cancelled.save!(validate: false)

    new_reg = CourseRegistration.new(course: course, participant: participant,
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false)

    assert new_reg.save(validate: false), "Neue Anmeldung nach Stornierung soll möglich sein"
  end

  test "single_session erlaubt unterschiedliche sessions, verhindert aber doppelte session" do
    course = Course.new(title: "Z", registration_mode: "single_session", registration_type: "single_session",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    course.save!(validate: false)

    participant = participants(:one)
    session_a = TrainingSession.create!(course: course, start_time: 1.day.from_now, end_time: 1.day.from_now + 1.hour)
    session_b = TrainingSession.create!(course: course, start_time: 2.days.from_now, end_time: 2.days.from_now + 1.hour)

    first = CourseRegistration.new(course: course, participant: participant, training_session: session_a,
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false)
    second = CourseRegistration.new(course: course, participant: participant, training_session: session_b,
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false)

    assert first.save(validate: false), "Anmeldung für erste Session soll möglich sein"
    assert second.save(validate: false), "Anmeldung für zweite Session soll möglich sein"

    duplicate_same_session = CourseRegistration.new(course: course, participant: participant, training_session: session_a,
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false)

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate_same_session.save!(validate: false)
    end
  end

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
