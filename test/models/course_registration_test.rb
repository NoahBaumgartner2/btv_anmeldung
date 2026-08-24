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

  test "allows semester registration despite existing abo-booked session in the same course" do
    # Reproduces: participant has an Abo (separate course) and already booked a single
    # session of courses(:one) via that Abo (abo_source_registration_id set, same
    # course_id). Registering for the full semester course must NOT be blocked by that.
    course = courses(:one)
    participant = participants(:parent_only_child)

    abo_course = Course.new(title: "Abo-Kurs", registration_type: "abo", registration_mode: "abo",
      abo_size: 10, has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    abo_course.save!(validate: false)
    abo_pass = CourseRegistration.new(course: abo_course, participant: participant,
      status: "bestätigt", payment_cleared: true, holiday_deduction_claimed: false,
      abo_entries_total: 10, abo_entries_used: 1)
    abo_pass.save!(validate: false)

    abo_booking = CourseRegistration.new(course: course, participant: participant,
      status: "bestätigt", payment_cleared: true, holiday_deduction_claimed: false,
      abo_source_registration_id: abo_pass.id)
    abo_booking.save!(validate: false)

    semester_registration = CourseRegistration.new(course: course, participant: participant,
      payment_cleared: false, holiday_deduction_claimed: false)

    assert semester_registration.valid?,
      "Expected no duplicate error despite existing abo booking, got: #{semester_registration.errors.full_messages.join(', ')}"
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

  # ── AHV-Pflicht richtet sich nach dem Kurs, nicht nach dem Alter ──────────────

  test "Anmeldung ohne AHV-Nummer schlägt fehl, wenn der Kurs sie verlangt" do
    course = Course.new(
      title: "AHV-Test-Kurs", registration_type: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      start_date: Date.new(2026, 9, 1), requires_ahv_number: true
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

  test "Anmeldung eines minderjährigen Teilnehmers ohne AHV-Nummer ist gültig, wenn der Kurs sie nicht verlangt" do
    course = Course.new(
      title: "AHV-Test-Kein-Pflichtfeld", registration_type: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      start_date: Date.new(2026, 9, 1), requires_ahv_number: false
    )
    course.save!(validate: false)

    participant = Participant.new(
      user: users(:one), first_name: "Jung", last_name: "Ohne AHV",
      date_of_birth: Date.new(2015, 12, 31), gender: "weiblich",
      phone_number: "0791000092", ahv_number: nil
    )
    participant.save!(validate: false)

    reg = CourseRegistration.new(
      course: course, participant: participant,
      payment_cleared: false, holiday_deduction_claimed: false
    )

    assert reg.valid?, "Anmeldung ohne AHV soll gültig sein, wenn der Kurs sie nicht verlangt, got: #{reg.errors.full_messages.join(', ')}"
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

  test "stornieren des Abo-Passes storniert auch noch aktive abo_bookings kaskadierend" do
    setup = make_abo_setup
    abo_reg      = setup[:abo_reg]
    target_course = setup[:target_course]

    session = target_course.training_sessions.create!(
      start_time: 2.days.from_now, end_time: 2.days.from_now + 1.hour, is_canceled: false
    )
    booking = CourseRegistration.new(
      course: target_course, participant: participants(:one),
      training_session: session,
      abo_source_registration_id: abo_reg.id,
      status: "bestätigt", payment_cleared: true
    )
    booking.save!(validate: false)

    abo_reg.update!(status: "storniert", cancelled_at: Time.current)

    assert_equal "storniert", booking.reload.status,
      "Kinder-Buchung muss beim Stornieren des Abo-Passes automatisch storniert werden"
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

  test "set_payment_expiry erneuert eine abgelaufene Frist bei erneutem Eintritt in ausstehend" do
    reg = CourseRegistration.new(course: paid_course, participant: participants(:one),
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false)
    reg.save!(validate: false)
    reg.update_column(:payment_expires_at, 1.hour.ago)

    reg.status = "storniert"
    reg.save!(validate: false)
    reg.status = "ausstehend"
    reg.save!(validate: false)

    assert_in_delta 48.hours.from_now.to_i, reg.payment_expires_at.to_i, 60
  end

  # ── merge_into_existing_abo! ─────────────────────────────────────────────

  def make_abo_course(abo_size: 10)
    course = Course.new(
      title: "Merge-Abo-Kurs", registration_type: "semester", registration_mode: "abo",
      has_payment: true, price_cents: 15_000, has_ticketing: false,
      allows_holiday_deduction: false, allows_trial: false, abo_size: abo_size
    )
    course.save!(validate: false)
    course
  end

  test "merge_into_existing_abo! summiert Eintritte und storniert die Quelle" do
    course = make_abo_course
    existing = CourseRegistration.new(
      course: course, participant: participants(:one), status: "bestätigt",
      payment_cleared: true, holiday_deduction_claimed: false,
      abo_entries_total: 10, abo_entries_used: 7
    )
    existing.save!(validate: false)

    topup = CourseRegistration.new(
      course: course, participant: participants(:one), status: "ausstehend",
      payment_cleared: false, holiday_deduction_claimed: false,
      abo_entries_total: 10, abo_entries_used: 0
    )
    topup.save!(validate: false)

    result = topup.merge_into_existing_abo!(payment_cleared: true)

    assert_equal existing, result
    existing.reload
    assert_equal 20, existing.abo_entries_total
    assert_equal 13, existing.abo_entries_remaining
    topup.reload
    assert_equal "storniert", topup.status
    assert topup.payment_cleared?
    assert_not_nil topup.cancelled_at
  end

  test "merge_into_existing_abo! gibt nil zurück ohne bestehenden Pass" do
    course = make_abo_course
    first_purchase = CourseRegistration.new(
      course: course, participant: participants(:one), status: "ausstehend",
      payment_cleared: false, holiday_deduction_claimed: false,
      abo_entries_total: 10, abo_entries_used: 0
    )
    first_purchase.save!(validate: false)

    assert_nil first_purchase.merge_into_existing_abo!
    assert_equal "ausstehend", first_purchase.reload.status
  end

  test "merge_into_existing_abo! gibt nil zurück für Nicht-Abo-Kurse" do
    course = Course.new(
      title: "Normalkurs", registration_type: "semester", has_payment: false,
      has_ticketing: false, allows_holiday_deduction: false
    )
    course.save!(validate: false)
    reg = CourseRegistration.new(
      course: course, participant: participants(:one), status: "bestätigt",
      payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)

    assert_nil reg.merge_into_existing_abo!
  end

  # ── claw_back_makeup_entry! ───────────────────────────────────────────────────

  test "claw_back_makeup_entry! nimmt einen ungenutzten Ausgleichseintritt zurück" do
    abo_course = Course.new(title: "Abo", registration_type: "abo", registration_mode: "abo",
      abo_size: 10, has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    abo_course.save!(validate: false)
    reg = CourseRegistration.new(course: abo_course, participant: participants(:one), status: "bestätigt",
      payment_cleared: true, holiday_deduction_claimed: false, abo_entries_total: 4, abo_entries_used: 2)
    reg.save!(validate: false)

    assert reg.claw_back_makeup_entry!
    assert_equal 3, reg.reload.abo_entries_total
    assert_equal 2, reg.abo_entries_used
  end

  test "claw_back_makeup_entry! storniert einen frisch angelegten, ungenutzten 1er-Pass komplett" do
    abo_course = Course.new(title: "Abo", registration_type: "abo", registration_mode: "abo",
      abo_size: 10, has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    abo_course.save!(validate: false)
    reg = CourseRegistration.new(course: abo_course, participant: participants(:one), status: "bestätigt",
      payment_cleared: true, holiday_deduction_claimed: false, abo_entries_total: 1, abo_entries_used: 0)
    reg.save!(validate: false)

    assert reg.claw_back_makeup_entry!
    assert_equal "storniert", reg.reload.status
  end

  test "claw_back_makeup_entry! gibt false zurück, wenn der Eintritt bereits verbraucht ist" do
    abo_course = Course.new(title: "Abo", registration_type: "abo", registration_mode: "abo",
      abo_size: 10, has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    abo_course.save!(validate: false)
    reg = CourseRegistration.new(course: abo_course, participant: participants(:one), status: "bestätigt",
      payment_cleared: true, holiday_deduction_claimed: false, abo_entries_total: 3, abo_entries_used: 3)
    reg.save!(validate: false)

    assert_not reg.claw_back_makeup_entry!
    assert_equal 3, reg.reload.abo_entries_total
  end

  # --- waitlist_position ---

  test "waitlist_position gibt nil zurück, wenn nicht auf der Warteliste" do
    course = Course.new(title: "Kurs", registration_type: "kurs", registration_mode: "single_session",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    course.save!(validate: false)
    reg = CourseRegistration.new(course: course, participant: participants(:one), status: "bestätigt")
    reg.save!(validate: false)

    assert_nil reg.waitlist_position
  end

  test "waitlist_position zaehlt frühere Wartelisten-Anmeldungen der gleichen Trainingssession" do
    course = Course.new(title: "Drop-In Warteliste", registration_type: "pro_training", registration_mode: "single_session",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    course.save!(validate: false)
    session = course.training_sessions.create!(start_time: 1.day.from_now, end_time: 1.day.from_now + 1.hour, is_canceled: false)
    other_session = course.training_sessions.create!(start_time: 2.days.from_now, end_time: 2.days.from_now + 1.hour, is_canceled: false)

    first = CourseRegistration.new(course: course, participant: participants(:one), training_session: session, status: "warteliste")
    first.save!(validate: false)
    second = CourseRegistration.new(course: course, participant: participants(:two), training_session: session, status: "warteliste")
    second.save!(validate: false)
    # Warteliste einer anderen Trainingssession darf nicht mitzählen.
    other = CourseRegistration.new(course: course, participant: participants(:parent_only_child), training_session: other_session, status: "warteliste")
    other.save!(validate: false)

    assert_equal 1, first.reload.waitlist_position
    assert_equal 2, second.reload.waitlist_position
    assert_equal 1, other.reload.waitlist_position
  end
end
