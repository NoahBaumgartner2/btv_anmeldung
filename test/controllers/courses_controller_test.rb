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

  test "index blendet Kurse ausserhalb des Registrierungsfensters für normale Familien aus" do
    old_course = @course
    terms(:two).update!(priority_registration_date: Date.new(2026, 12, 21))
    hidden_course = Course.new(
      title: "Noch nicht offener Nachfolge-Kurs", registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      previous_course: old_course, start_date: Date.new(2027, 1, 11),
      term: terms(:two), public_registration_days: 14
    )
    hidden_course.save!(validate: false)

    sign_out users(:admin)
    sign_in users(:parent_only)

    travel_to(Date.new(2027, 1, 1)) do
      get courses_url
    end

    assert_response :success
    assert_not_includes response.body, hidden_course.title
  end

  test "index zeigt Trainingszeit auf der Kurskarte" do
    date = Date.current.next_occurring(:monday)
    start_time = Time.zone.local(date.year, date.month, date.day, 17, 0)
    @course.training_sessions.create!(start_time: start_time, end_time: start_time + 90.minutes, is_canceled: false)

    get courses_url
    assert_response :success
    assert_includes @response.body, "Montag, 17:00–18:30"
  end

  test "index zeigt bei Abo-Kursen 'Durchgehend verfügbar' statt 'Termin folgt'" do
    Course.new(
      title: "Abo-Kurs", category: "Turnen", registration_type: "abo", registration_mode: "abo",
      abo_size: 10, has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    ).save!(validate: false)

    get courses_url

    assert_response :success
    assert_includes @response.body, "Durchgehend verfügbar"
    assert_not_includes @response.body, "Termin folgt"
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

  test "Kurs kann mit Semester/Quartal (term_id) erstellt werden" do
    term = terms(:one)

    post courses_url, params: { course: {
      allows_holiday_deduction: @course.allows_holiday_deduction, description: @course.description,
      end_date: @course.end_date, has_payment: @course.has_payment, has_ticketing: @course.has_ticketing,
      location: @course.location, registration_type: @course.registration_type,
      start_date: @course.start_date, title: @course.title, term_id: term.id
    } }

    assert_equal term, Course.last.term
  end

  test "new zeigt Semester/Quartal-Auswahl im Kursformular" do
    get new_course_url
    assert_response :success
    assert_includes response.body, "Semester/Quartal"
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

  test "manual_enroll mit trial meldet Teilnehmer zum Schnuppern an (Drop-In)" do
    course = Course.new(
      title: "Drop-In Schnupperkurs", category: "Turnen",
      registration_type: "pro_training", registration_mode: "single_session",
      allows_trial: true, has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      max_participants: 5
    )
    course.save!(validate: false)
    session = course.training_sessions.create!(
      start_time: 5.days.from_now, end_time: 5.days.from_now + 1.hour, is_canceled: false
    )

    post manual_enroll_course_url(course), params: {
      participant_id: participants(:one).id, trial: "true", trial_session_id: session.id
    }

    reg = CourseRegistration.last
    assert_equal "schnuppern", reg.status
    assert_equal participants(:one), reg.participant
    assert_equal session.id, reg.training_session_id
    assert_redirected_to manage_course_path(course)
  end

  test "manual_enroll mit trial bei Drop-In verlangt trial_session_id" do
    course = Course.new(
      title: "Drop-In Schnupperkurs ohne Session", category: "Turnen",
      registration_type: "pro_training", registration_mode: "single_session",
      allows_trial: true, has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    )
    course.save!(validate: false)
    course.training_sessions.create!(
      start_time: 5.days.from_now, end_time: 5.days.from_now + 1.hour, is_canceled: false
    )

    assert_no_difference("CourseRegistration.count") do
      post manual_enroll_course_url(course), params: { participant_id: participants(:one).id, trial: "true" }
    end
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

  test "manual_enroll mit trial erlaubt erneutes Schnuppern derselben Kategorie (Admin-Override)" do
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
    session = other_course.training_sessions.create!(
      start_time: 5.days.from_now, end_time: 5.days.from_now + 1.hour, is_canceled: false
    )

    assert_difference("CourseRegistration.count", 1) do
      post manual_enroll_course_url(other_course), params: {
        participant_id: participants(:one).id, trial: "true", trial_session_id: session.id
      }
    end
    assert_equal "schnuppern", CourseRegistration.last.status
  end

  test "manual_enroll mit trial setzt Warteliste wenn Kurs voll" do
    course = Course.new(
      title: "Voller Schnupperkurs", category: "Turnen",
      registration_type: "pro_training", registration_mode: "single_session",
      allows_trial: true, has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      max_participants: 1, enable_waitlist: true
    )
    course.save!(validate: false)
    session = course.training_sessions.create!(
      start_time: 5.days.from_now, end_time: 5.days.from_now + 1.hour, is_canceled: false
    )

    CourseRegistration.new(
      course: course, participant: participants(:two),
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false,
      training_session_id: session.id
    ).save!(validate: false)

    post manual_enroll_course_url(course), params: {
      participant_id: participants(:one).id, trial: "true", trial_session_id: session.id
    }

    assert_equal "warteliste", CourseRegistration.last.status
  end

  test "manual_enroll importiert bestehendes Abo mit Resteintritten" do
    course = Course.new(
      title: "Abo-Kurs Import", category: "Turnen",
      registration_type: "abo", registration_mode: "abo", abo_size: 10,
      has_payment: true, price_cents: 5000, has_ticketing: false, allows_holiday_deduction: false
    )
    course.save!(validate: false)

    post manual_enroll_course_url(course), params: {
      participant_id: participants(:one).id, abo_remaining_entries: "5"
    }

    reg = CourseRegistration.last
    assert_equal 5, reg.abo_entries_total
    assert_equal 0, reg.abo_entries_used
    assert reg.payment_cleared?
    assert_equal "bestätigt", reg.status
    assert_enqueued_email_with CourseRegistrationMailer, :abo_imported, args: [ reg ]
  end

  test "manual_enroll ohne Import setzt volles Abo-Kontingent aus course.abo_size" do
    course = Course.new(
      title: "Abo-Kurs Normal", category: "Turnen",
      registration_type: "abo", registration_mode: "abo", abo_size: 10,
      has_payment: true, price_cents: 5000, has_ticketing: false, allows_holiday_deduction: false
    )
    course.save!(validate: false)

    post manual_enroll_course_url(course), params: { participant_id: participants(:one).id }

    reg = CourseRegistration.last
    assert_equal 10, reg.abo_entries_total
    assert_equal 0, reg.abo_entries_used
    assert_not reg.payment_cleared?
    assert_enqueued_email_with CourseRegistrationMailer, :confirmation, args: [ reg ]
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

  test "manage zeigt Trainingsauswahl wenn Sessions vorhanden" do
    course = Course.new(
      title: "Schnupperkurs mit Sessions", category: "Turnen",
      registration_type: "pro_training", registration_mode: "single_session",
      allows_trial: true, has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    )
    course.save!(validate: false)
    session = course.training_sessions.create!(
      start_time: 5.days.from_now, end_time: 5.days.from_now + 1.hour, is_canceled: false
    )

    get manage_course_url(course)

    assert_response :success
    assert_includes response.body, "manual_trial_session"
    assert_includes response.body, I18n.l(session.start_time)
  end

  test "manage zeigt Hinweis wenn keine Trainings für Schnuppern vorhanden" do
    course = Course.new(
      title: "Schnupperkurs ohne Sessions", category: "Turnen",
      registration_type: "pro_training", registration_mode: "single_session",
      allows_trial: true, has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    )
    course.save!(validate: false)

    get manage_course_url(course)

    assert_response :success
    assert_includes response.body, I18n.t("course_registrations.form.trial_no_sessions")
  end

  # ── Admin: manuelle Anmeldung mit ungültiger/neuer E-Mail ──────────────

  test "manual_enroll mit ungültiger E-Mail zeigt Fehlermeldung statt 500" do
    assert_no_difference([ "User.count", "Participant.count", "CourseRegistration.count" ]) do
      post manual_enroll_course_url(@course), params: {
        new_family_email: "not-an-email", participant: { first_name: "Test", last_name: "Kind" }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "gültige E-Mail-Adresse"
  end

  test "manual_enroll email_only ohne Namen zeigt Fehlermeldung" do
    assert_no_difference([ "User.count", "Participant.count", "CourseRegistration.count" ]) do
      post manual_enroll_course_url(@course), params: {
        new_family_email: "neue.familie@example.com", email_only: "true",
        participant: { first_name: "", last_name: "" }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Vor- und Nachname"
  end

  test "manual_enroll email_only legt Platzhalter-Teilnehmer an und verschickt complete_profile-Mail" do
    assert_difference([ "User.count", "Participant.count", "CourseRegistration.count" ], 1) do
      assert_enqueued_emails 1 do
        post manual_enroll_course_url(@course), params: {
          new_family_email: "neue.familie@example.com", email_only: "true",
          participant: { first_name: "Mia", last_name: "Muster" }
        }
      end
    end

    participant = Participant.last
    assert_equal "Mia", participant.first_name
    assert_equal "Muster", participant.last_name
    assert_nil participant.date_of_birth
    assert_equal "neue.familie@example.com", participant.user.email

    job = enqueued_jobs.find { |j| j[:args].first == "ParticipantMailer" }
    assert_equal "complete_profile", job[:args][1]
    assert_redirected_to manage_course_path(@course)
  end

  test "manual_enroll Fehler bei allows_trial-Kurs crasht nicht (fehlende @trial_sessions)" do
    course = Course.new(
      title: "Trial Fehlertest", category: "Turnen",
      registration_type: "semester", registration_mode: "semester",
      allows_trial: true, has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    )
    course.save!(validate: false)

    post manual_enroll_course_url(course), params: {
      new_family_email: "not-an-email", participant: { first_name: "Test", last_name: "Kind" }
    }

    assert_response :unprocessable_entity
  end

  test "manual_enroll zeigt bei Fehler das 'Neue Familie erstellen'-Panel direkt an" do
    post manual_enroll_course_url(@course), params: {
      new_family_email: "not-an-email", participant: { first_name: "Test", last_name: "Kind" }
    }

    assert_response :unprocessable_entity
    assert_match(/data-manual-enroll-target="createPanel" class="\s*"/, response.body)
    assert_match(/data-manual-enroll-target="searchPanel" class="hidden"/, response.body)
  end

  # ── roll_over (manueller Modus) ─────────────────────────────────────────

  test "roll_over erstellt den Nachfolge-Kurs, wenn fällig" do
    terms(:two).update!(priority_registration_date: Date.new(2026, 12, 22))
    course = Course.new(
      title: "Manueller Rollover-Kurs", category: "Turnen",
      registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      term: terms(:one), auto_rollover: false
    )
    course.save!(validate: false)

    travel_to(Date.new(2026, 12, 22)) do # Vorlauf-Datum erreicht
      assert_difference("Course.count", 1) do
        post roll_over_course_url(course)
      end
    end

    assert_redirected_to manage_course_path(Course.last)
  end

  test "roll_over lehnt ab, wenn noch nicht fällig" do
    terms(:two).update!(priority_registration_date: Date.new(2030, 1, 1))
    course = Course.new(
      title: "Noch nicht fälliger Kurs", category: "Turnen",
      registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      term: terms(:one), auto_rollover: false
    )
    course.save!(validate: false)

    assert_no_difference("Course.count") do
      post roll_over_course_url(course)
    end

    assert_redirected_to manage_course_path(course)
    assert_match "noch nicht bereit", flash[:alert]
  end

  test "roll_over ist nur für Admins zugänglich" do
    course = Course.new(
      title: "Kurs", category: "Turnen", registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    )
    course.save!(validate: false)

    sign_out users(:admin)
    sign_in users(:one) # Trainer, kein Admin

    post roll_over_course_url(course)
    assert_redirected_to root_path
  end

  # ── self_enroll (Trainer meldet sich selbst gratis an) ───────────────────────

  def build_fresh_trainer(date_of_birth: Date.new(1990, 1, 1))
    user = User.create!(
      email: "self-enroll-#{SecureRandom.hex(4)}@example.com",
      password: "password123", confirmed_at: Time.current, privacy_accepted: true
    )
    trainer = Trainer.create!(
      user: user, first_name: "Test", last_name: "Trainer",
      phone: "+41 79 111 22 33", date_of_birth: date_of_birth, gender: "weiblich",
      ahv_number: "756.9999.8888.77", street: "Weg", house_number: "1",
      zip_code: "3000", city: "Bern", country: "CH", nationality: "CH", mother_tongue: "DE"
    )
    trainer.sync_self_participant!
    trainer
  end

  test "self_enroll meldet den Trainer kostenlos und bestätigt an" do
    trainer = build_fresh_trainer
    course = Course.new(title: "Gratis-Test", registration_type: "semester", registration_mode: "semester",
      has_payment: true, has_ticketing: false, allows_holiday_deduction: false)
    course.price_cents = 10000
    course.save!(validate: false)

    sign_in trainer.user

    assert_difference "CourseRegistration.count", 1 do
      post self_enroll_course_path(course)
    end

    reg = CourseRegistration.last
    assert_equal "bestätigt", reg.status
    assert reg.payment_cleared?
    assert_equal trainer.self_participant, reg.participant
    assert_redirected_to course_path(course)
  end

  test "self_enroll blockiert bei Altersbeschränkung" do
    trainer = build_fresh_trainer(date_of_birth: Date.new(1990, 1, 1)) # 36 Jahre alt
    course = Course.new(title: "Nur für Kinder", registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false, min_age: 5, max_age: 12)
    course.save!(validate: false)

    sign_in trainer.user

    assert_no_difference "CourseRegistration.count" do
      post self_enroll_course_path(course)
    end

    assert_redirected_to course_path(course)
    assert_match "Altersbeschränkung", flash[:alert]
  end

  test "self_enroll lehnt eine erneute Anmeldung ab" do
    trainer = build_fresh_trainer
    course = Course.new(title: "Doppelt", registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    course.save!(validate: false)
    CourseRegistration.new(course: course, participant: trainer.self_participant, status: "bestätigt",
      payment_cleared: true, holiday_deduction_claimed: false).save!(validate: false)

    sign_in trainer.user

    assert_no_difference "CourseRegistration.count" do
      post self_enroll_course_path(course)
    end

    assert_match "bereits", flash[:alert]
  end

  test "self_enroll ohne vollständiges Trainer-Profil verweist auf Mein Profil" do
    trainer = build_fresh_trainer
    trainer.self_participant.update_columns(date_of_birth: nil)
    course = Course.new(title: "Profil-Check", registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    course.save!(validate: false)

    sign_in trainer.user

    assert_no_difference "CourseRegistration.count" do
      post self_enroll_course_path(course)
    end

    assert_redirected_to my_profile_path
  end

  test "self_enroll ist blockiert, wenn der Kurs es nicht erlaubt" do
    trainer = build_fresh_trainer
    course = Course.new(title: "Kein Selbst-Enroll", registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false, allows_trainer_self_enroll: false)
    course.save!(validate: false)

    sign_in trainer.user

    assert_no_difference "CourseRegistration.count" do
      post self_enroll_course_path(course)
    end

    assert_redirected_to course_path(course)
    assert_match "nicht aktiviert", flash[:alert]
  end

  test "self_enroll ist blockiert, wenn der globale Schalter aus ist" do
    FeatureSetting.current.update!(trainer_self_enroll_enabled: false)
    trainer = build_fresh_trainer
    course = Course.new(title: "Global aus", registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    course.save!(validate: false)

    sign_in trainer.user

    assert_no_difference "CourseRegistration.count" do
      post self_enroll_course_path(course)
    end

    assert_redirected_to course_path(course)
    assert_match "nicht aktiviert", flash[:alert]
  end
end
