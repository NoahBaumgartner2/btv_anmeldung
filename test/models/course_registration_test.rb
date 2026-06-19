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
    course = Course.new(title: "Z", registration_mode: "single_session",
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

  test "shows schnuppern-specific error when normal registration attempted with existing schnuppern" do
    course = Course.new(title: "Schnupper-Test", registration_type: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    course.save!(validate: false)

    participant = participants(:parent_only_child)

    trial = CourseRegistration.new(course: course, participant: participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false)
    trial.save!(validate: false)

    duplicate = CourseRegistration.new(course: course, participant: participant,
      payment_cleared: false, holiday_deduction_claimed: false)

    assert_not duplicate.valid?
    assert_match I18n.t("course_registrations.errors.duplicate_schnuppern"), duplicate.errors.full_messages.join
    assert_no_match I18n.t("course_registrations.errors.duplicate_registration"), duplicate.errors.full_messages.join
  end

  # ── fully_confirmed? ─────────────────────────────────────────────────────────

  def paid_course
    course = Course.new(title: "Paid", registration_type: "semester",
      has_payment: true, has_ticketing: false, allows_holiday_deduction: false)
    course.price_cents = 5000
    course.save!(validate: false)
    course
  end

  def free_course
    course = Course.new(title: "Free", registration_type: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    course.save!(validate: false)
    course
  end

  test "fully_confirmed? true für bestätigt + bezahlt bei zahlungspflichtigem Kurs" do
    reg = CourseRegistration.new(course: paid_course, participant: participants(:one),
      status: "bestätigt", payment_cleared: true, holiday_deduction_claimed: false)
    assert reg.fully_confirmed?
  end

  test "fully_confirmed? false für bestätigt + unbezahlt bei zahlungspflichtigem Kurs" do
    reg = CourseRegistration.new(course: paid_course, participant: participants(:one),
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false)
    assert_not reg.fully_confirmed?
  end

  test "fully_confirmed? true für bestätigt + unbezahlt bei Gratis-Kurs" do
    reg = CourseRegistration.new(course: free_course, participant: participants(:one),
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false)
    assert reg.fully_confirmed?
  end

  test "fully_confirmed? true für schnuppern + unbezahlt" do
    reg = CourseRegistration.new(course: paid_course, participant: participants(:one),
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false)
    assert reg.fully_confirmed?
  end

  test "fully_confirmed? false für ausstehend" do
    reg = CourseRegistration.new(course: paid_course, participant: participants(:one),
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false)
    assert_not reg.fully_confirmed?
  end

  # ── payable? ─────────────────────────────────────────────────────────────────

  test "payable? true für ausstehend + unbezahlt bei zahlungspflichtigem Kurs" do
    reg = CourseRegistration.new(course: paid_course, participant: participants(:one),
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false)
    assert reg.payable?
  end

  test "payable? true für bestätigt + unbezahlt bei zahlungspflichtigem Kurs" do
    reg = CourseRegistration.new(course: paid_course, participant: participants(:one),
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false)
    assert reg.payable?
  end

  test "payable? false für bestätigt + bereits bezahlt" do
    reg = CourseRegistration.new(course: paid_course, participant: participants(:one),
      status: "bestätigt", payment_cleared: true, holiday_deduction_claimed: false)
    assert_not reg.payable?
  end

  test "payable? false bei Gratis-Kurs" do
    reg = CourseRegistration.new(course: free_course, participant: participants(:one),
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false)
    assert_not reg.payable?
  end

  test "payable? false für storniert und warteliste" do
    %w[storniert warteliste].each do |status|
      reg = CourseRegistration.new(course: paid_course, participant: participants(:one),
        status: status, payment_cleared: false, holiday_deduction_claimed: false)
      assert_not reg.payable?, "payable? muss für Status #{status} false sein"
    end
  end

  test "payable? true für schnuppern + unbezahlt bei zahlungspflichtigem Kurs" do
    # Beim Umwandeln eines Schnupperplatzes bleibt der Status "schnuppern" bis zur
    # bestätigten Zahlung – er muss daher zahlbar sein.
    reg = CourseRegistration.new(course: paid_course, participant: participants(:one),
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false)
    assert reg.payable?
  end

  test "payable? false für schnuppern bei Gratis-Kurs" do
    reg = CourseRegistration.new(course: free_course, participant: participants(:one),
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false)
    assert_not reg.payable?
  end

  # ── AHV-Pflicht nach Altersregel ─────────────────────────────────────────────

  test "Anmeldung eines Teilnehmers <=20 ohne AHV-Nummer schlägt fehl" do
    course = Course.new(
      title: "AHV-Test-Kurs", registration_type: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      start_date: Date.new(2026, 9, 1)
    )
    course.save!(validate: false)

    participant = Participant.new(
      user: users(:one), first_name: "Jung", last_name: "Ohne AHV",
      date_of_birth: Date.new(2006, 1, 1), gender: "weiblich",
      phone_number: "0791000091", ahv_number: nil
    )
    participant.save!(validate: false)

    reg = CourseRegistration.new(
      course: course, participant: participant,
      payment_cleared: false, holiday_deduction_claimed: false
    )

    assert_not reg.valid?
    assert_match "AHV-Nummer", reg.errors.full_messages.join
  end

  test "Anmeldung eines Teilnehmers >20 ohne AHV-Nummer ist gültig" do
    course = Course.new(
      title: "AHV-Test-Erwachsene", registration_type: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      start_date: Date.new(2026, 9, 1)
    )
    course.save!(validate: false)

    participant = Participant.new(
      user: users(:one), first_name: "Erwachsen", last_name: "Ohne AHV",
      date_of_birth: Date.new(2004, 12, 31), gender: "weiblich",
      phone_number: "0791000092", ahv_number: nil
    )
    participant.save!(validate: false)

    reg = CourseRegistration.new(
      course: course, participant: participant,
      payment_cleared: false, holiday_deduction_claimed: false
    )

    assert reg.valid?, "Anmeldung >20 ohne AHV soll gültig sein, got: #{reg.errors.full_messages.join(', ')}"
  end

  # ── displayable_abo_sessions / abo_booked_session_ids ───────────────────────

  def make_abo_setup
    abo_course = Course.new(
      title: "Abo-Kurs", registration_mode: "abo",
      category: "Turnen", abo_size: 5,
      start_date: Date.today, end_date: 1.year.from_now.to_date,
      registration_type: "kurs"
    )
    abo_course.save!(validate: false)

    target_course = Course.new(
      title: "Zielkurs", registration_mode: "single_session",
      category: "Turnen",
      start_date: Date.today, end_date: 1.year.from_now.to_date,
      registration_type: "kurs"
    )
    target_course.save!(validate: false)

    abo_reg = CourseRegistration.new(
      course: abo_course, participant: participants(:one),
      status: "bestätigt", abo_entries_total: 5, abo_entries_used: 0,
      payment_cleared: true
    )
    abo_reg.save!(validate: false)

    { abo_reg: abo_reg, target_course: target_course }
  end

  test "displayable_abo_sessions enthält künftige Sessions inkl. bereits gebuchter" do
    setup = make_abo_setup
    abo_reg      = setup[:abo_reg]
    target_course = setup[:target_course]

    future_session = target_course.training_sessions.create!(
      start_time: 2.days.from_now, end_time: 2.days.from_now + 1.hour, is_canceled: false
    )

    booking = CourseRegistration.new(
      course: target_course, participant: participants(:one),
      training_session: future_session,
      abo_source_registration_id: abo_reg.id,
      status: "bestätigt", payment_cleared: true
    )
    booking.save!(validate: false)

    sessions = abo_reg.displayable_abo_sessions
    assert_includes sessions.map(&:id), future_session.id,
                    "displayable_abo_sessions soll bereits gebuchte Sessions enthalten"
  end

  test "bookable_abo_sessions schliesst bereits gebuchte Sessions aus" do
    setup = make_abo_setup
    abo_reg      = setup[:abo_reg]
    target_course = setup[:target_course]

    future_session = target_course.training_sessions.create!(
      start_time: 2.days.from_now, end_time: 2.days.from_now + 1.hour, is_canceled: false
    )

    booking = CourseRegistration.new(
      course: target_course, participant: participants(:one),
      training_session: future_session,
      abo_source_registration_id: abo_reg.id,
      status: "bestätigt", payment_cleared: true
    )
    booking.save!(validate: false)

    sessions = abo_reg.bookable_abo_sessions
    assert_not_includes sessions.map(&:id), future_session.id,
                        "bookable_abo_sessions soll bereits gebuchte Sessions NICHT enthalten"
  end

  test "abo_booked_session_ids liefert IDs nicht-stornierter Buchungen" do
    setup = make_abo_setup
    abo_reg      = setup[:abo_reg]
    target_course = setup[:target_course]

    session_a = target_course.training_sessions.create!(
      start_time: 2.days.from_now, end_time: 2.days.from_now + 1.hour, is_canceled: false
    )
    session_b = target_course.training_sessions.create!(
      start_time: 3.days.from_now, end_time: 3.days.from_now + 1.hour, is_canceled: false
    )

    active_booking = CourseRegistration.new(
      course: target_course, participant: participants(:one),
      training_session: session_a,
      abo_source_registration_id: abo_reg.id,
      status: "bestätigt", payment_cleared: true
    )
    active_booking.save!(validate: false)

    cancelled_booking = CourseRegistration.new(
      course: target_course, participant: participants(:parent_only_child),
      training_session: session_b,
      abo_source_registration_id: abo_reg.id,
      status: "storniert", payment_cleared: true
    )
    cancelled_booking.save!(validate: false)

    ids = abo_reg.abo_booked_session_ids
    assert_includes ids, session_a.id, "aktive Buchung muss in abo_booked_session_ids sein"
    assert_not_includes ids, session_b.id, "stornierte Buchung darf NICHT in abo_booked_session_ids sein"
  end

  test "allows normal registration after schnuppern is storniert" do
    course = Course.new(title: "Schnupper-Storniert-Test", registration_type: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    course.save!(validate: false)

    participant = participants(:parent_only_child)

    trial = CourseRegistration.new(course: course, participant: participant,
      status: "storniert", payment_cleared: false, holiday_deduction_claimed: false)
    trial.save!(validate: false)

    new_reg = CourseRegistration.new(course: course, participant: participant,
      payment_cleared: false, holiday_deduction_claimed: false)

    assert new_reg.valid?, "Registration after cancelled schnuppern should be valid, got: #{new_reg.errors.full_messages.join(', ')}"
  end

  # ── set_payment_expiry ───────────────────────────────────────────────────────

  test "set_payment_expiry übernimmt trial_expires_at bei Schnupper-Konversion" do
    reg = CourseRegistration.new(course: paid_course, participant: participants(:one),
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false,
      trial_expires_at: 5.days.from_now)
    reg.save!(validate: false)

    reg.status = "ausstehend"
    reg.save!(validate: false)

    assert_in_delta 5.days.from_now.to_i, reg.payment_expires_at.to_i, 60
  end

  test "set_payment_expiry nutzt 48h ohne Schnupperhintergrund" do
    reg = CourseRegistration.new(course: paid_course, participant: participants(:one),
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false)
    reg.save!(validate: false)

    assert_in_delta 48.hours.from_now.to_i, reg.payment_expires_at.to_i, 60
  end

  test "set_payment_expiry hält 48h-Untergrenze ein" do
    reg = CourseRegistration.new(course: paid_course, participant: participants(:one),
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false,
      trial_expires_at: 1.hour.from_now)
    reg.save!(validate: false)

    reg.status = "ausstehend"
    reg.save!(validate: false)

    assert_in_delta 48.hours.from_now.to_i, reg.payment_expires_at.to_i, 60
  end
end
