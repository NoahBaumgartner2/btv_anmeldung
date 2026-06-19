require "test_helper"

class CourseRegistrationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionMailer::TestHelper

  setup do
    @parent = users(:one)
    @other_parent = users(:two)
    @registration = course_registrations(:one)
    @future_session = training_sessions(:future)
    @past_session = training_sessions(:one)

    @trial_parent = users(:parent_only)
    @trial_participant = participants(:parent_only_child)
    @trial_course = Course.new(
      title: "Schnupper-Kurs",
      registration_type: "semester",
      registration_mode: "semester",
      has_payment: false,
      has_ticketing: false,
      allows_holiday_deduction: false,
      allows_trial: true,
      requires_ahv_number: true
    )
    @trial_course.save!(validate: false)
    @trial_session = @trial_course.training_sessions.create!(
      start_time: 5.days.from_now, end_time: 5.days.from_now + 1.hour, is_canceled: false
    )
  end

  # ── unsubscribe_from_session ─────────────────────────────────────────────

  test "creates abgemeldet attendance for own registration" do
    sign_in @parent

    assert_difference "Attendance.count", 1 do
      post unsubscribe_from_session_course_registration_path(@registration),
           params: { training_session_id: @future_session.id }
    end

    assert_redirected_to participants_path
    assert_equal "abgemeldet", Attendance.last.status
    assert_match @registration.participant.first_name, flash[:notice]
  end

  test "updates existing attendance to abgemeldet" do
    sign_in @parent
    # Pre-existing attendance (e.g. trainer toggled anwesend)
    existing = @future_session.attendances.create!(
      course_registration: @registration,
      status: "anwesend"
    )

    assert_no_difference "Attendance.count" do
      post unsubscribe_from_session_course_registration_path(@registration),
           params: { training_session_id: @future_session.id }
    end

    assert_equal "abgemeldet", existing.reload.status
    assert_redirected_to participants_path
  end

  test "cannot unsubscribe from another user's registration" do
    sign_in @other_parent

    post unsubscribe_from_session_course_registration_path(@registration),
         params: { training_session_id: @future_session.id }

    assert_redirected_to root_path
    assert_match "Zugriff verweigert", flash[:alert]
  end

  test "cannot unsubscribe from session within 1 hour" do
    sign_in @parent

    post unsubscribe_from_session_course_registration_path(@registration),
         params: { training_session_id: @past_session.id }

    assert_redirected_to participants_path
    assert_match "1 Stunde", flash[:alert]
    assert_equal 0, @past_session.attendances.where(status: "abgemeldet").count
  end

  test "redirects to login when not authenticated" do
    post unsubscribe_from_session_course_registration_path(@registration),
         params: { training_session_id: @future_session.id }

    assert_redirected_to new_user_session_path
  end

  test "unsubscribe_from_session storniert Schnupper-Anmeldung vollständig" do
    sign_in @trial_parent

    schnupper_course = Course.new(
      title: "Schnupper-Abmelde-Test", registration_type: "semester",
      registration_mode: "semester", has_payment: false, has_ticketing: false,
      allows_holiday_deduction: false
    )
    schnupper_course.save!(validate: false)

    future_session = schnupper_course.training_sessions.create!(
      start_time: 2.days.from_now, end_time: 2.days.from_now + 1.hour, is_canceled: false
    )

    reg = CourseRegistration.new(
      course: schnupper_course, participant: @trial_participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)

    assert_no_difference "Attendance.count" do
      post unsubscribe_from_session_course_registration_path(reg),
           params: { training_session_id: future_session.id }
    end

    assert_redirected_to participants_path
    reg.reload
    assert_equal "storniert", reg.status
    assert_not reg.trial?
    assert reg.cancelled_at.present?
  end

  test "unsubscribe_from_session legt Attendance an und belässt Status bei nicht-Schnupper-Anmeldung" do
    sign_in @parent

    assert_difference "Attendance.count", 1 do
      post unsubscribe_from_session_course_registration_path(@registration),
           params: { training_session_id: @future_session.id }
    end

    assert_redirected_to participants_path
    assert_equal "abgemeldet", Attendance.last.status
    @registration.reload
    assert_not_equal "storniert", @registration.status
  end

  # ── scan ────────────────────────────────────────────────────────────────────

  test "scan redirects with alert when session_id not found" do
    sign_in @parent  # users(:one) ist auch Trainer (trainer fixture :one)

    post scan_course_registration_path(@registration), params: { session_id: 0 }

    assert_redirected_to root_path
    assert_match "nicht gefunden", flash[:alert]
  end

  test "scan returns 404 JSON when session_id not found" do
    sign_in @parent  # users(:one) ist auch Trainer (trainer fixture :one)

    post scan_course_registration_path(@registration),
         params: { session_id: 0 },
         headers: { "Accept" => "application/json" }

    assert_response :not_found
    body = JSON.parse(response.body)
    assert_equal false, body["success"]
    assert_includes body["message"], "nicht gefunden"
  end

  # ── Schnuppern ────────────────────────────────────────────────────────────

  test "creates schnupper registration when trial param is true and course allows trial" do
    sign_in @trial_parent

    assert_difference "CourseRegistration.count", 1 do
      post course_registrations_path, params: {
        course_registration: {
          course_id: @trial_course.id,
          participant_id: @trial_participant.id,
          trial_session_id: @trial_session.id
        },
        trial: "true"
      }
    end

    reg = CourseRegistration.last
    assert_equal "schnuppern", reg.status
    assert_equal @trial_session.id, reg.trial_session_id
    assert_redirected_to course_registration_path(reg)
    assert_match "schnuppert", flash[:notice]
  end

  test "rejects trial when course does not allow trial" do
    @trial_course.update_column(:allows_trial, false)
    sign_in @trial_parent

    assert_no_difference "CourseRegistration.count" do
      post course_registrations_path, params: {
        course_registration: {
          course_id: @trial_course.id,
          participant_id: @trial_participant.id,
          trial_session_id: @trial_session.id
        },
        trial: "true"
      }
    end

    assert_response :unprocessable_entity
  end

  test "rejects trial when participant already trialed in same category" do
    existing = CourseRegistration.new(
      course: @trial_course, participant: @trial_participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    existing.save!(validate: false)

    sign_in @trial_parent

    assert_no_difference "CourseRegistration.count" do
      post course_registrations_path, params: {
        course_registration: {
          course_id: @trial_course.id,
          participant_id: @trial_participant.id,
          trial_session_id: @trial_session.id
        },
        trial: "true"
      }
    end

    assert_response :unprocessable_entity
  end

  test "does not redirect to payment when trial even if course has payment" do
    @trial_course.update_columns(has_payment: true, price_cents: 10_000)
    sign_in @trial_parent

    assert_difference "CourseRegistration.count", 1 do
      post course_registrations_path, params: {
        course_registration: {
          course_id: @trial_course.id,
          participant_id: @trial_participant.id,
          trial_session_id: @trial_session.id
        },
        trial: "true"
      }
    end

    reg = CourseRegistration.last
    assert_equal "schnuppern", reg.status
    assert_redirected_to course_registration_path(reg)
  end

  test "rejects semester trial without trial_session_id" do
    sign_in @trial_parent

    assert_no_difference "CourseRegistration.count" do
      post course_registrations_path, params: {
        course_registration: {
          course_id: @trial_course.id,
          participant_id: @trial_participant.id
        },
        trial: "true"
      }
    end

    assert_response :unprocessable_entity
  end

  test "creates semester trial with trial_session and sets expiry to session start plus 7 days" do
    sign_in @trial_parent

    assert_difference "CourseRegistration.count", 1 do
      post course_registrations_path, params: {
        course_registration: {
          course_id: @trial_course.id,
          participant_id: @trial_participant.id,
          trial_session_id: @trial_session.id
        },
        trial: "true"
      }
    end

    reg = CourseRegistration.last
    assert_equal @trial_session.id, reg.trial_session_id
    assert_in_delta (@trial_session.start_time + 7.days).to_f, reg.trial_expires_at.to_f, 1.0
  end

  test "rejects trial with session belonging to another course" do
    other_course = Course.new(
      title: "Anderer Kurs", registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      allows_trial: true, requires_ahv_number: true
    )
    other_course.save!(validate: false)
    foreign_session = other_course.training_sessions.create!(
      start_time: 5.days.from_now, end_time: 5.days.from_now + 1.hour, is_canceled: false
    )

    sign_in @trial_parent

    assert_no_difference "CourseRegistration.count" do
      post course_registrations_path, params: {
        course_registration: {
          course_id: @trial_course.id,
          participant_id: @trial_participant.id,
          trial_session_id: foreign_session.id
        },
        trial: "true"
      }
    end

    assert_response :unprocessable_entity
  end

  # ── Schnupperplatz / bestätigt-unbezahlt → zur Zahlung weiterleiten ─────────

  test "reguläre Anmeldung bei bestehendem Schnupperplatz (kostenpflichtig) leitet zur Zahlung weiter und behält Schnupperstatus bis zur Zahlung" do
    @trial_course.update_columns(has_payment: true, price_cents: 10_000)
    existing = CourseRegistration.new(
      course: @trial_course, participant: @trial_participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    existing.save!(validate: false)
    sign_in @trial_parent

    assert_no_difference "CourseRegistration.count" do
      post course_registrations_path, params: {
        course_registration: { course_id: @trial_course.id, participant_id: @trial_participant.id }
      }
    end

    # Der Schnupperplatz bleibt erhalten (Platz reserviert, 7-Tage-Frist läuft weiter),
    # bis die Zahlung bestätigt ist – nicht "ausstehend".
    assert_equal "schnuppern", existing.reload.status
    assert_redirected_to checkout_preview_registration_path(existing)
  end

  test "reguläre Anmeldung bei bestätigt-aber-unbezahlt (kostenpflichtig) leitet zur Zahlung weiter ohne neuen Datensatz" do
    @trial_course.update_columns(has_payment: true, price_cents: 10_000)
    existing = CourseRegistration.new(
      course: @trial_course, participant: @trial_participant,
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false
    )
    existing.save!(validate: false)
    sign_in @trial_parent

    assert_no_difference "CourseRegistration.count" do
      post course_registrations_path, params: {
        course_registration: { course_id: @trial_course.id, participant_id: @trial_participant.id }
      }
    end

    assert_equal "bestätigt", existing.reload.status
    assert_redirected_to checkout_preview_registration_path(existing)
  end

  test "reguläre Anmeldung bei bestätigt und bereits bezahlt bleibt blockiert" do
    @trial_course.update_columns(has_payment: true, price_cents: 10_000)
    existing = CourseRegistration.new(
      course: @trial_course, participant: @trial_participant,
      status: "bestätigt", payment_cleared: true, holiday_deduction_claimed: false
    )
    existing.save!(validate: false)
    sign_in @trial_parent

    assert_no_difference "CourseRegistration.count" do
      post course_registrations_path, params: {
        course_registration: { course_id: @trial_course.id, participant_id: @trial_participant.id }
      }
    end

    assert_response :unprocessable_entity
    assert_match I18n.t("course_registrations.errors.duplicate_registration"), response.body
    assert_equal "bestätigt", existing.reload.status
  end

  test "reguläre Anmeldung bei bestehender Warteliste bleibt blockiert" do
    @trial_course.update_columns(has_payment: true, price_cents: 10_000)
    existing = CourseRegistration.new(
      course: @trial_course, participant: @trial_participant,
      status: "warteliste", payment_cleared: false, holiday_deduction_claimed: false
    )
    existing.save!(validate: false)
    sign_in @trial_parent

    assert_no_difference "CourseRegistration.count" do
      post course_registrations_path, params: {
        course_registration: { course_id: @trial_course.id, participant_id: @trial_participant.id }
      }
    end

    assert_response :unprocessable_entity
    assert_equal "warteliste", existing.reload.status
  end

  test "reguläre Anmeldung bei bestehendem Schnupperplatz (Gratiskurs) bestätigt den bestehenden Datensatz" do
    existing = CourseRegistration.new(
      course: @trial_course, participant: @trial_participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    existing.save!(validate: false)
    sign_in @trial_parent

    assert_no_difference "CourseRegistration.count" do
      post course_registrations_path, params: {
        course_registration: { course_id: @trial_course.id, participant_id: @trial_participant.id }
      }
    end

    assert_equal "bestätigt", existing.reload.status
    assert_redirected_to course_registration_path(existing)
    assert_equal I18n.t("course_registrations.flash.trial_converted"), flash[:notice]
  end

  # ── convert_trial ──────────────────────────────────────────────────────────

  test "convert_trial (kostenpflichtig) behält Schnupperstatus und leitet zur Zahlung weiter" do
    @trial_course.update_columns(has_payment: true, price_cents: 10_000)
    trial = CourseRegistration.new(
      course: @trial_course, participant: @trial_participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    trial.save!(validate: false)
    sign_in @trial_parent

    # Status bleibt "schnuppern", bis die Zahlung bestätigt ist – Platz bleibt
    # reserviert; es darf noch keine Bestätigungs-Mail verschickt werden.
    assert_no_enqueued_emails do
      post convert_trial_course_registration_path(trial)
    end

    assert_equal "schnuppern", trial.reload.status
    assert_redirected_to checkout_preview_registration_path(trial)
  end

  test "convert_trial (Gratiskurs) bestätigt direkt und verschickt Bestätigung" do
    trial = CourseRegistration.new(
      course: @trial_course, participant: @trial_participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    trial.save!(validate: false)
    sign_in @trial_parent

    assert_enqueued_email_with CourseRegistrationMailer, :confirmation, args: [ trial ] do
      post convert_trial_course_registration_path(trial)
    end

    assert_equal "bestätigt", trial.reload.status
    assert_redirected_to course_registration_path(trial)
    assert_equal I18n.t("course_registrations.flash.trial_converted"), flash[:notice]
  end

  test "convert_trial lehnt Nicht-Schnupper-Anmeldung ab" do
    @trial_course.update_columns(has_payment: true, price_cents: 10_000)
    reg = CourseRegistration.new(
      course: @trial_course, participant: @trial_participant,
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)
    sign_in @trial_parent

    post convert_trial_course_registration_path(reg)

    assert_equal "ausstehend", reg.reload.status
    assert_redirected_to course_registration_path(reg)
    assert_equal I18n.t("course_registrations.flash.not_a_trial"), flash[:alert]
  end

  # ── trial_eligible ────────────────────────────────────────────────────────

  test "trial_eligible returns eligible true for participant who never trialed" do
    sign_in @trial_parent
    get trial_eligible_course_registrations_path,
        params: { course_id: @trial_course.id, participant_id: @trial_participant.id },
        headers: { "Accept" => "application/json" }
    assert_response :ok
    assert_equal true, JSON.parse(response.body)["eligible"]
  end

  test "trial_eligible returns eligible false when participant already trialed in category" do
    reg = CourseRegistration.new(course: @trial_course, participant: @trial_participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false)
    reg.save!(validate: false)
    sign_in @trial_parent
    get trial_eligible_course_registrations_path,
        params: { course_id: @trial_course.id, participant_id: @trial_participant.id },
        headers: { "Accept" => "application/json" }
    assert_equal false, JSON.parse(response.body)["eligible"]
  end

  test "trial_eligible returns eligible false when participant already confirmed in same category" do
    reg = CourseRegistration.new(course: @trial_course, participant: @trial_participant,
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false)
    reg.save!(validate: false)
    sign_in @trial_parent
    get trial_eligible_course_registrations_path,
        params: { course_id: @trial_course.id, participant_id: @trial_participant.id },
        headers: { "Accept" => "application/json" }
    assert_equal false, JSON.parse(response.body)["eligible"]
  end

  test "trial_eligible returns eligible false when course does not allow trial" do
    @trial_course.update_column(:allows_trial, false)
    sign_in @trial_parent
    get trial_eligible_course_registrations_path,
        params: { course_id: @trial_course.id, participant_id: @trial_participant.id },
        headers: { "Accept" => "application/json" }
    assert_equal false, JSON.parse(response.body)["eligible"]
  end

  test "trial_eligible returns eligible false for participant belonging to another user" do
    other_participant = participants(:one)
    sign_in @trial_parent
    get trial_eligible_course_registrations_path,
        params: { course_id: @trial_course.id, participant_id: other_participant.id },
        headers: { "Accept" => "application/json" }
    assert_equal false, JSON.parse(response.body)["eligible"]
  end

  # ── new (Schnupper-Setup) ───────────────────────────────────────────────────

  test "new lädt @trial_sessions und rendert die Schnuppertraining-Auswahl für Trial-Semesterkurs" do
    sign_in @trial_parent
    get new_course_registration_path(course_id: @trial_course.id)
    assert_response :ok
    # Stimulus-Verdrahtung am Container vorhanden
    assert_select "[data-controller='trial-check'][data-trial-check-allows-trial-value='true']"
    # Teilnehmer-Select korrekt verdrahtet
    assert_select "select[data-trial-check-target='participantSelect']"
    # Schnuppertraining-Auswahl gerendert (kommende, nicht abgesagte Session vorhanden)
    assert_select "select[data-trial-check-target='trialSelect']"
    assert_select "[data-trial-check-target='trialEmpty']", false
  end

  # ── mark_as_paid ──────────────────────────────────────────────────────────

  test "mark_as_paid markiert Registration als bezahlt (admin only)" do
    admin = users(:admin)
    sign_in admin

    reg = course_registrations(:one)
    reg.update_columns(payment_cleared: false, status: "ausstehend")

    post mark_as_paid_course_registration_path(reg)

    reg.reload
    assert reg.payment_cleared?
    assert_equal "bestätigt", reg.status
    assert_redirected_to manage_course_path(reg.course)
  end

  test "mark_as_paid ist idempotent – doppelter Aufruf ändert nichts" do
    admin = users(:admin)
    sign_in admin

    reg = course_registrations(:one)
    reg.update_columns(payment_cleared: true, status: "bestätigt", sumup_transaction_id: "orig-tx")

    post mark_as_paid_course_registration_path(reg)

    reg.reload
    assert reg.payment_cleared?, "payment_cleared soll true bleiben"
    assert_equal "bestätigt", reg.status
  end

  test "mark_as_paid verweigert Zugriff für Eltern" do
    sign_in @parent

    reg = course_registrations(:one)
    post mark_as_paid_course_registration_path(reg)

    assert_redirected_to root_path
  end

  # ── Abo ───────────────────────────────────────────────────────────────────

  # ── Race Condition / Overbooking ─────────────────────────────────────────────

  test "zweite Anmeldung landet auf Warteliste wenn Kurs voll ist" do
    course = Course.new(
      title: "Voller Kurs", registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      max_participants: 1, enable_waitlist: true
    )
    course.save!(validate: false)

    # Simuliert einen direkten DB-Insert (wie Race-Condition-Gewinner)
    # participants(:one) gehört users(:one) – hier direkt eingefügt ohne Controller
    CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false
    ).save!(validate: false)

    # Zweite Anmeldung über den Controller (trial_parent ist kein Trainer/Admin)
    sign_in @trial_parent
    assert_difference "CourseRegistration.count", 1 do
      post course_registrations_path, params: {
        course_registration: { course_id: course.id, participant_id: @trial_participant.id }
      }
    end

    assert_equal "warteliste", CourseRegistration.last.status,
      "Zweite Anmeldung muss auf Warteliste da Kurs voll (Overbooking-Schutz)"
  end

  test "erste Anmeldung für freien Kurs bekommt Status bestätigt" do
    course = Course.new(
      title: "Freier Kurs", registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      max_participants: 5, enable_waitlist: true
    )
    course.save!(validate: false)

    sign_in @trial_parent
    assert_difference "CourseRegistration.count", 1 do
      post course_registrations_path, params: {
        course_registration: { course_id: course.id, participant_id: @trial_participant.id }
      }
    end

    assert_equal "bestätigt", CourseRegistration.last.status
  end

  test "abo_entries_total wird beim Anmelden auf abo_size gesetzt" do
    abo_course = Course.new(
      title: "10er-Abo Kurs",
      registration_type: "semester",
      registration_mode: "abo",
      has_payment: false,
      has_ticketing: false,
      allows_holiday_deduction: false,
      allows_trial: false,
      abo_size: 10
    )
    abo_course.save!(validate: false)

    sign_in @trial_parent

    assert_difference "CourseRegistration.count", 1 do
      post course_registrations_path, params: {
        course_registration: {
          course_id: abo_course.id,
          participant_id: @trial_participant.id
        }
      }
    end

    reg = CourseRegistration.last
    assert_equal 10, reg.abo_entries_total
    assert_equal 0, reg.abo_entries_used
  end

  # ── update_abo_entries (Rest-Guthaben anpassen) ──────────────────────────

  def build_abo_registration(used: 3, total: 10)
    course = Course.new(
      title: "Acro4you", registration_type: "semester", registration_mode: "abo",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      allows_trial: false, abo_size: total
    )
    course.save!(validate: false)
    CourseTrainer.create!(course: course, trainer: trainers(:one)) # user one = zugewiesener Trainer
    reg = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "bestätigt", abo_entries_total: total, abo_entries_used: used
    )
    reg.save!(validate: false)
    [ course, reg ]
  end

  test "admin passt Rest-Guthaben an, abo_entries_used bleibt unverändert" do
    _course, reg = build_abo_registration(used: 3, total: 10)
    sign_in users(:admin)

    post update_abo_entries_course_registration_path(reg), params: { remaining_entries: 5 }

    reg.reload
    assert_equal 3, reg.abo_entries_used          # unverändert
    assert_equal 8, reg.abo_entries_total         # 3 verbraucht + 5 verbleibend
    assert_equal 5, reg.abo_entries_remaining
  end

  test "zugewiesener Trainer darf Rest-Guthaben anpassen" do
    _course, reg = build_abo_registration(used: 2, total: 10)
    sign_in @parent # users(:one) == trainer one, zugewiesen

    post update_abo_entries_course_registration_path(reg), params: { remaining_entries: 4 }

    reg.reload
    assert_equal 2, reg.abo_entries_used
    assert_equal 6, reg.abo_entries_total
  end

  test "nicht zugewiesener Trainer wird abgewiesen" do
    _course, reg = build_abo_registration(used: 2, total: 10)
    sign_in @other_parent # users(:two) == trainer two, NICHT zugewiesen

    post update_abo_entries_course_registration_path(reg), params: { remaining_entries: 1 }

    assert_redirected_to root_path
    assert_equal 10, reg.reload.abo_entries_total
  end

  test "Elternteil ohne Trainer-Rolle wird abgewiesen" do
    _course, reg = build_abo_registration(used: 2, total: 10)
    sign_in @trial_parent # parent_only, kein Trainer/Admin

    post update_abo_entries_course_registration_path(reg), params: { remaining_entries: 1 }

    assert_redirected_to root_path
    assert_equal 10, reg.reload.abo_entries_total
  end

  test "negative Eingabe wird abgewiesen" do
    course, reg = build_abo_registration(used: 2, total: 10)
    sign_in users(:admin)

    post update_abo_entries_course_registration_path(reg), params: { remaining_entries: -1 }

    assert_redirected_to manage_course_path(course)
    assert_equal 10, reg.reload.abo_entries_total
  end

  test "update_abo_entries bei Nicht-Abo-Kurs greift nicht" do
    sign_in users(:admin)
    course = @registration.course # kein Abo-Kurs
    assert_not course.abo?
    original_total = @registration.abo_entries_total

    post update_abo_entries_course_registration_path(@registration), params: { remaining_entries: 5 }

    assert_redirected_to manage_course_path(course)
    assert_equal original_total.inspect, @registration.reload.abo_entries_total.inspect
  end

  # ── show / Zahlungs-Header ──────────────────────────────────────────────────

  test "show zeigt title_payment_pending wenn Zahlung offen und Status ausstehend" do
    paid_course = Course.new(
      title: "Zahlungskurs", registration_type: "semester", registration_mode: "semester",
      has_payment: true, price_cents: 10_000,
      has_ticketing: false, allows_holiday_deduction: false
    )
    paid_course.save!(validate: false)

    reg = CourseRegistration.new(
      course: paid_course, participant: @trial_participant,
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)

    sign_in @trial_parent

    old_token = ENV["SUMUP_ACCESS_TOKEN"]
    ENV["SUMUP_ACCESS_TOKEN"] = "test-token"
    get course_registration_path(reg)
    ENV["SUMUP_ACCESS_TOKEN"] = old_token

    assert_response :success
    assert_includes response.body, I18n.t("course_registrations.show.title_payment_pending")
    assert_not_includes response.body, I18n.t("course_registrations.show.title_payment")
  end

  test "show zeigt title_payment wenn Status bestätigt und Zahlung noch offen (confirmed_unpaid)" do
    paid_course = Course.new(
      title: "Zahlungskurs bestätigt", registration_type: "semester", registration_mode: "semester",
      has_payment: true, price_cents: 10_000,
      has_ticketing: false, allows_holiday_deduction: false
    )
    paid_course.save!(validate: false)

    reg = CourseRegistration.new(
      course: paid_course, participant: @trial_participant,
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)

    sign_in @trial_parent

    old_token = ENV["SUMUP_ACCESS_TOKEN"]
    ENV["SUMUP_ACCESS_TOKEN"] = "test-token"
    get course_registration_path(reg)
    ENV["SUMUP_ACCESS_TOKEN"] = old_token

    assert_response :success
    assert_includes response.body, I18n.t("course_registrations.show.title_payment")
    assert_not_includes response.body, I18n.t("course_registrations.show.title_payment_pending")
  end

  # ── edit/update durch Admin (fremde Anmeldung) ───────────────────────────

  test "admin sieht im edit-Formular den Teilnehmer statt der Leer-Warnung" do
    sign_in users(:admin)

    get edit_course_registration_path(@registration)

    assert_response :success
    participant = @registration.participant
    assert_includes @response.body, "#{participant.first_name} #{participant.last_name}"
    assert_not_includes @response.body, I18n.t("course_registrations.form.no_participants")
  end

  test "admin-update mit Status-Änderung behält participant_id" do
    sign_in users(:admin)
    original_participant_id = @registration.participant_id

    patch course_registration_path(@registration), params: {
      course_registration: {
        course_id: @registration.course_id,
        participant_id: original_participant_id,
        status: "warteliste",
        payment_cleared: false
      }
    }

    assert_redirected_to course_path(@registration.course)
    @registration.reload
    assert_equal "warteliste", @registration.status
    assert_equal original_participant_id, @registration.participant_id
  end

  # ── mark_as_paid ──────────────────────────────────────────────────────────

  test "mark_as_paid markiert ausstehend-Anmeldung als bezahlt und bestätigt" do
    @trial_course.update_columns(has_payment: true, price_cents: 10_000)
    reg = CourseRegistration.new(
      course: @trial_course, participant: @trial_participant,
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)

    sign_in users(:admin)
    post mark_as_paid_course_registration_path(reg)

    reg.reload
    assert reg.payment_cleared?
    assert_equal "bestätigt", reg.status
    assert_redirected_to manage_course_path(@trial_course)
  end

  test "mark_as_paid fängt Unique-Index-Konflikt ab, statt 500 zu werfen" do
    @trial_course.update_columns(has_payment: true, price_cents: 10_000)

    # Bereits aktive (bestätigte) Anmeldung desselben Teilnehmers im selben Kurs
    confirmed = CourseRegistration.new(
      course: @trial_course, participant: @trial_participant,
      status: "bestätigt", payment_cleared: true, holiday_deduction_claimed: false
    )
    confirmed.save!(validate: false)

    # Parallele ausstehend-Anmeldung (vom partiellen Unique-Index ausgenommen)
    pending = CourseRegistration.new(
      course: @trial_course, participant: @trial_participant,
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false
    )
    pending.save!(validate: false)

    sign_in users(:admin)
    post mark_as_paid_course_registration_path(pending)

    assert_redirected_to manage_course_path(@trial_course)
    assert_equal I18n.t("course_registrations.flash.mark_paid_duplicate"), flash[:alert]

    pending.reload
    assert_not pending.payment_cleared?
    assert_equal "ausstehend", pending.status
  end
end
