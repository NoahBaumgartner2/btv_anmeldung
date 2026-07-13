require "test_helper"

class CoursesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @course = courses(:one)
    sign_in users(:admin)
  end

  test "should get index" do
    get courses_url
    assert_response :success
  end

  test "index zeigt Trainingszeit auf der Kurskarte" do
    date = Date.current.next_occurring(:monday)
    start_time = Time.zone.local(date.year, date.month, date.day, 17, 0)
    @course.training_sessions.create!(start_time: start_time, end_time: start_time + 90.minutes, is_canceled: false)

    get courses_url
    assert_response :success
    assert_includes @response.body, "Montag, 17:00–18:30"
  end

  test "should get new" do
    get new_course_url
    assert_response :success
  end

  test "should create course" do
    assert_difference("Course.count") do
      post courses_url, params: { course: { allows_holiday_deduction: @course.allows_holiday_deduction, description: @course.description, end_date: @course.end_date, has_payment: @course.has_payment, has_ticketing: @course.has_ticketing, location: @course.location, registration_type: @course.registration_type, start_date: @course.start_date, title: @course.title } }
    end

    assert_redirected_to manage_course_path(Course.last)
  end

  test "should show course" do
    get course_url(@course)
    assert_response :success
  end

  test "manage zeigt offene ausstehend-Anmeldung trotz neuerer Stornierung desselben Kindes" do
    course = Course.new(
      title: "Bezahlkurs", registration_type: "semester", registration_mode: "semester",
      has_payment: true, price_cents: 10_000, has_ticketing: false, allows_holiday_deduction: false,
      max_participants: 1, enable_waitlist: true
    )
    course.save!(validate: false)

    # Älterer, noch offener Checkout (belegt den Platz, blockiert die Warteliste)
    pending = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false,
      payment_expires_at: 48.hours.from_now
    )
    pending.save!(validate: false)
    pending.update_column(:created_at, 2.hours.ago)

    # Neuere Stornierung desselben Kindes (würde die offene Anmeldung sonst verdecken)
    cancelled = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "storniert", payment_cleared: false, holiday_deduction_claimed: false
    )
    cancelled.save!(validate: false)
    cancelled.update_column(:created_at, 1.hour.ago)

    get manage_course_path(course)

    assert_response :success
    # Die offene (aktive) Anmeldung muss sichtbar sein – nicht von der Stornierung verdeckt.
    assert_includes @response.body, I18n.t("courses.manage.status_open"),
      "Offene ausstehend-Anmeldung muss trotz neuerer Stornierung sichtbar bleiben"
  end

  test "manage zählt bestätigt-aber-unbezahlt als vollwertigen Teilnehmer" do
    course = Course.new(
      title: "Bezahlkurs Barzahlung", registration_type: "semester", registration_mode: "semester",
      has_payment: true, price_cents: 10_000, has_ticketing: false, allows_holiday_deduction: false,
      max_participants: 12, enable_waitlist: true
    )
    course.save!(validate: false)

    # Manuell erfasst: bestätigt, Zahlung offen → soll als Teilnehmer zählen
    CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false
    ).save!(validate: false)

    get manage_course_path(course)

    assert_response :success
    # bestätigt-Zählung enthält die unbezahlte Anmeldung (1 bestätigt, nicht 0)
    assert_includes @response.body, "1 #{I18n.t('courses.manage.confirmed_label')}",
      "Bestätigt-aber-unbezahlt muss als bestätigter Teilnehmer gezählt werden"
  end

  # ── registration_type wird aus registration_mode abgeleitet ────────────────

  test "create mit registration_mode quartal setzt registration_type quartal" do
    post courses_url, params: { course: {
      title: "Quartalskurs", registration_mode: "quartal",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    } }
    assert_equal "quartal", Course.last.registration_type
    assert_equal "Quartalskurs", Course.last.registration_type_label
  end

  test "create mit registration_mode abo setzt registration_type abo" do
    post courses_url, params: { course: {
      title: "Abo-Kurs", registration_mode: "abo",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    } }
    assert_equal "abo", Course.last.registration_type
  end

  test "update auf registration_mode quartal aktualisiert registration_type" do
    @course.update_columns(registration_mode: "semester", registration_type: "semester")
    patch course_url(@course), params: { course: { registration_mode: "quartal" } }
    assert_equal "quartal", @course.reload.registration_type
  end

  test "registration_type_label übersetzt quartal nicht mehr als Semesterkurs" do
    @course.update_columns(registration_mode: "quartal", registration_type: "quartal")
    assert_equal "Quartalskurs", @course.registration_type_label
    assert_not_equal "Semesterkurs", @course.registration_type_label
  end

  test "Kapazitätserhöhung stuft Wartelisten-Anmeldungen hoch" do
    course = Course.new(
      title: "Montagskurs", registration_type: "semester", registration_mode: "semester",
      has_payment: false, price_cents: 0, has_ticketing: false, allows_holiday_deduction: false,
      max_participants: 1, enable_waitlist: true
    )
    course.save!(validate: false)

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

    patch course_url(course), params: { course: { max_participants: 2 } }

    assert_equal "bestätigt", waitlisted.reload.status,
      "Wartelisten-Anmeldung muss nach Erhöhung der Teilnehmerzahl nachrücken"
  end

  test "unveränderte Teilnehmerzahl stuft Warteliste nicht hoch" do
    course = Course.new(
      title: "Montagskurs", registration_type: "semester", registration_mode: "semester",
      has_payment: false, price_cents: 0, has_ticketing: false, allows_holiday_deduction: false,
      max_participants: 1, enable_waitlist: true
    )
    course.save!(validate: false)

    CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false
    ).save!(validate: false)

    waitlisted = CourseRegistration.new(
      course: course, participant: participants(:two),
      status: "warteliste", payment_cleared: false, holiday_deduction_claimed: false
    )
    waitlisted.save!(validate: false)

    patch course_url(course), params: { course: { title: "Montagskurs neu" } }

    assert_equal "warteliste", waitlisted.reload.status
  end

  test "should get edit" do
    get edit_course_url(@course)
    assert_response :success
  end

  test "should update course" do
    patch course_url(@course), params: { course: { allows_holiday_deduction: @course.allows_holiday_deduction, description: @course.description, end_date: @course.end_date, has_payment: @course.has_payment, has_ticketing: @course.has_ticketing, location: @course.location, registration_type: @course.registration_type, start_date: @course.start_date, title: @course.title } }
    assert_redirected_to manage_course_path(@course)
  end

  test "should destroy course" do
    assert_difference("Course.count", -1) do
      delete course_url(@course)
    end

    assert_redirected_to courses_path
  end

  test "confirm_destroy deletes course with correct password" do
    sign_in users(:admin)
    assert_difference("Course.count", -1) do
      post confirm_destroy_course_url(@course), params: { admin_password: "password" }
    end
    assert_redirected_to courses_url
  end

  test "confirm_destroy does not delete course with wrong password" do
    sign_in users(:admin)
    assert_no_difference("Course.count") do
      post confirm_destroy_course_url(@course), params: { admin_password: "wrongpassword" }
    end
    assert_redirected_to course_url(@course)
  end

  # ── Schnupper-Button: category statt registration_type ─────────────────────

  test "Schnupper-Button erscheint bei Kurs anderer Kategorie" do
    parent = users(:parent_only)
    participant = participants(:parent_only_child)  # hat AHV-Nummer gesetzt

    course_a = Course.new(
      title: "Kunstturnen Plus A", category: "Kunstturnen Plus",
      registration_type: "semester", registration_mode: "semester",
      allows_trial: true, requires_ahv_number: true,
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    )
    course_a.save!(validate: false)
    course_a.training_sessions.create!(
      start_time: 10.days.from_now, end_time: 10.days.from_now + 1.hour, is_canceled: false
    )

    course_b = Course.new(
      title: "Tanzen B", category: "Tanzen",
      registration_type: "semester", registration_mode: "semester",
      allows_trial: true, requires_ahv_number: true,
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    )
    course_b.save!(validate: false)
    course_b.training_sessions.create!(
      start_time: 10.days.from_now, end_time: 10.days.from_now + 1.hour, is_canceled: false
    )

    # Participant hat in Kurs A (Kategorie "Kunstturnen Plus") geschnuppert
    CourseRegistration.new(
      course: course_a, participant: participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    ).save!(validate: false)

    sign_in parent
    get course_url(course_b)

    assert_response :success
    assert_includes response.body, "trial=true",
      "Schnupper-Button soll bei anderer Kategorie erscheinen"
  end

  test "Schnupper-Button fehlt bei Kurs derselben Kategorie" do
    parent = users(:parent_only)
    participant = participants(:parent_only_child)

    course_a = Course.new(
      title: "Kunstturnen Plus A", category: "Kunstturnen Plus",
      registration_type: "semester", registration_mode: "semester",
      allows_trial: true, requires_ahv_number: true,
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    )
    course_a.save!(validate: false)
    course_a.training_sessions.create!(
      start_time: 10.days.from_now, end_time: 10.days.from_now + 1.hour, is_canceled: false
    )

    # Participant hat in dieser Kategorie geschnuppert
    CourseRegistration.new(
      course: course_a, participant: participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    ).save!(validate: false)

    sign_in parent
    get course_url(course_a)

    assert_response :success
    assert_not_includes response.body, "trial=true",
      "Schnupper-Button soll in derselben Kategorie nicht erscheinen"
  end

  test "manage rendert für Admin inkl. Verschieben-Funktion" do
    # course_registrations(:one) liegt auf courses(:one) → Teilnehmer wird gelistet
    get manage_course_url(@course)
    assert_response :success
    assert_includes response.body, I18n.t("courses.manage.move_button")
  end

  # ── Admin: manuelle Schnuppern-Anmeldung ────────────────────────────────

  test "manual_enroll mit trial meldet Teilnehmer zum Schnuppern an" do
    course = Course.new(
      title: "Drop-In Schnupperkurs", category: "Turnen",
      registration_type: "pro_training", registration_mode: "single_session",
      allows_trial: true, has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      max_participants: 5
    )
    course.save!(validate: false)

    post manual_enroll_course_url(course), params: {
      participant_id: participants(:one).id, trial: "true"
    }

    reg = CourseRegistration.last
    assert_equal "schnuppern", reg.status
    assert_equal participants(:one), reg.participant
    assert_redirected_to manage_course_path(course)
  end

  test "manual_enroll mit trial bei Semesterkurs verlangt trial_session_id" do
    course = Course.new(
      title: "Semesterkurs Schnuppern", category: "Turnen",
      registration_type: "semester", registration_mode: "semester",
      allows_trial: true, has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    )
    course.save!(validate: false)
    session = course.training_sessions.create!(
      start_time: 5.days.from_now, end_time: 5.days.from_now + 1.hour, is_canceled: false
    )

    assert_no_difference("CourseRegistration.count") do
      post manual_enroll_course_url(course), params: { participant_id: participants(:one).id, trial: "true" }
    end

    assert_difference("CourseRegistration.count", 1) do
      post manual_enroll_course_url(course), params: {
        participant_id: participants(:one).id, trial: "true", trial_session_id: session.id
      }
    end
    assert_equal "schnuppern", CourseRegistration.last.status
    assert_equal session, CourseRegistration.last.trial_session
  end

  test "manual_enroll mit trial blockiert erneutes Schnuppern derselben Kategorie" do
    course = Course.new(
      title: "Drop-In Schnupperkurs 2", category: "Turnen",
      registration_type: "pro_training", registration_mode: "single_session",
      allows_trial: true, has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    )
    course.save!(validate: false)

    CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    ).save!(validate: false)

    other_course = Course.new(
      title: "Drop-In Schnupperkurs 3", category: "Turnen",
      registration_type: "pro_training", registration_mode: "single_session",
      allows_trial: true, has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    )
    other_course.save!(validate: false)

    assert_no_difference("CourseRegistration.count") do
      post manual_enroll_course_url(other_course), params: { participant_id: participants(:one).id, trial: "true" }
    end
    assert_redirected_to manage_course_path(other_course)
  end

  test "manual_enroll mit trial setzt Warteliste wenn Kurs voll" do
    course = Course.new(
      title: "Voller Schnupperkurs", category: "Turnen",
      registration_type: "pro_training", registration_mode: "single_session",
      allows_trial: true, has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      max_participants: 1, enable_waitlist: true
    )
    course.save!(validate: false)

    CourseRegistration.new(
      course: course, participant: participants(:two),
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false
    ).save!(validate: false)

    post manual_enroll_course_url(course), params: { participant_id: participants(:one).id, trial: "true" }

    assert_equal "warteliste", CourseRegistration.last.status
  end

  test "manage zeigt Schnuppern-Checkbox bei allows_trial-Kurs" do
    course = Course.new(
      title: "Schnupperkurs Checkbox", category: "Turnen",
      registration_type: "pro_training", registration_mode: "single_session",
      allows_trial: true, has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    )
    course.save!(validate: false)

    get manage_course_url(course)

    assert_response :success
    assert_includes response.body, "Nur schnuppern"
  end

  test "manage zeigt keine Schnuppern-Checkbox ohne allows_trial" do
    course = Course.new(
      title: "Normalkurs Checkbox", category: "Turnen",
      registration_type: "pro_training", registration_mode: "single_session",
      allows_trial: false, has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    )
    course.save!(validate: false)

    get manage_course_url(course)

    assert_response :success
    assert_not_includes response.body, "Nur schnuppern"
  end
end
