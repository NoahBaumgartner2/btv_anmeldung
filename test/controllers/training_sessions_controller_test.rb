require "test_helper"

class TrainingSessionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @training_session = training_sessions(:one)
    sign_in users(:admin)
  end

  test "should get index" do
    get training_sessions_url
    assert_response :success
  end

  test "should get new" do
    get new_training_session_url
    assert_response :success
  end

  test "should create training_session" do
    assert_difference("TrainingSession.count") do
      post training_sessions_url, params: {
        training_session: {
          course_id:   @training_session.course_id,
          end_time:    @training_session.end_time,
          is_canceled: @training_session.is_canceled,
          start_time:  @training_session.start_time
        }
      }
    end

    assert_redirected_to manage_course_path(TrainingSession.last.course)
  end

  test "should show training_session" do
    get training_session_url(@training_session)
    assert_response :success
  end

  test "show zeigt Wartelisten-Anmeldungen für dieses Training in Reihenfolge der Anmeldung" do
    course = Course.new(title: "Drop-In Warteliste Show", registration_type: "pro_training", registration_mode: "single_session",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    course.save!(validate: false)
    session = course.training_sessions.create!(start_time: 1.day.from_now, end_time: 1.day.from_now + 1.hour, is_canceled: false)

    first = CourseRegistration.new(course: course, participant: participants(:one), training_session: session, status: "warteliste")
    first.save!(validate: false)
    second = CourseRegistration.new(course: course, participant: participants(:two), training_session: session, status: "warteliste")
    second.save!(validate: false)

    get training_session_url(session)

    assert_response :success
    first_pos  = response.body.index(participants(:one).first_name)
    second_pos = response.body.index(participants(:two).first_name)
    assert first_pos, "#{participants(:one).first_name} nicht in der Warteliste angezeigt"
    assert second_pos, "#{participants(:two).first_name} nicht in der Warteliste angezeigt"
    assert first_pos < second_pos, "Wartelisten-Reihenfolge stimmt nicht mit der Anmeldereihenfolge überein"
  end

  test "Schnupper-Anmeldung erscheint nur beim gewählten Training in der Präsenzkontrolle" do
    course = Course.new(
      title: "Schnupper-Präsenz", registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false, allows_trial: true
    )
    course.save!(validate: false)
    session_a = course.training_sessions.create!(start_time: 2.days.from_now, end_time: 2.days.from_now + 1.hour, is_canceled: false)
    session_b = course.training_sessions.create!(start_time: 9.days.from_now, end_time: 9.days.from_now + 1.hour, is_canceled: false)

    # Schnupper-Anmeldung für Session A
    trial = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "schnuppern", trial_session_id: session_a.id, payment_cleared: false
    )
    trial.save!(validate: false)

    # Regulär bestätigt (ohne Session-Bindung) – erscheint in beiden
    confirmed = CourseRegistration.new(
      course: course, participant: participants(:two),
      status: "bestätigt", payment_cleared: false
    )
    confirmed.save!(validate: false)

    get training_session_url(session_a)
    assert_response :success
    assert_match participants(:one).first_name, @response.body, "Schnupperer muss bei gewähltem Training (A) erscheinen"
    assert_match participants(:two).first_name, @response.body

    get training_session_url(session_b)
    assert_response :success
    assert_no_match(/#{Regexp.escape(participants(:one).first_name)}/, @response.body,
      "Schnupperer darf NICHT bei anderem Training (B) erscheinen")
    assert_match participants(:two).first_name, @response.body, "Bestätigter erscheint weiterhin bei jedem Training"
  end

  test "Abo-Einzelbuchung erscheint nur beim gebuchten Training in der Präsenzkontrolle" do
    course = Course.new(
      title: "10er-Abo", registration_type: "abo", registration_mode: "abo",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    )
    course.save!(validate: false)
    monday    = course.training_sessions.create!(start_time: 2.days.from_now, end_time: 2.days.from_now + 1.hour, is_canceled: false)
    wednesday = course.training_sessions.create!(start_time: 4.days.from_now, end_time: 4.days.from_now + 1.hour, is_canceled: false)

    abo_source = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "bestätigt", abo_entries_total: 10, abo_entries_used: 0, payment_cleared: false
    )
    abo_source.save!(validate: false)

    # Einzelbuchung: nur für den Montagstermin
    monday_booking = CourseRegistration.new(
      course: course, participant: participants(:one), training_session_id: monday.id,
      abo_source_registration_id: abo_source.id, status: "bestätigt", payment_cleared: false
    )
    monday_booking.save!(validate: false)

    get training_session_url(monday)
    assert_response :success
    assert_match participants(:one).first_name, @response.body, "Abo-Buchung muss beim gebuchten Termin (Montag) erscheinen"

    get training_session_url(wednesday)
    assert_response :success
    assert_no_match(/#{Regexp.escape(participants(:one).first_name)}/, @response.body,
      "Abo-Buchung darf NICHT bei einem nicht gebuchten Termin (Mittwoch) erscheinen")
  end

  test "should get edit" do
    get edit_training_session_url(@training_session)
    assert_response :success
  end

  test "should update training_session" do
    patch training_session_url(@training_session), params: {
      training_session: {
        course_id:   @training_session.course_id,
        end_time:    @training_session.end_time,
        is_canceled: @training_session.is_canceled,
        start_time:  @training_session.start_time
      }
    }
    assert_redirected_to training_session_url(@training_session)
  end

  test "should destroy training_session" do
    future = training_sessions(:future)

    assert_difference("TrainingSession.count", -1) do
      delete training_session_url(future)
    end

    assert_redirected_to manage_course_path(future.course)
  end

  test "destroy blockiert vergangene Trainings, um Anwesenheitskontrollen zu erhalten" do
    assert_no_difference("TrainingSession.count") do
      delete training_session_url(@training_session)
    end

    assert_redirected_to manage_course_path(@training_session.course)
    assert_equal "Vergangene Trainings können nicht gelöscht werden, um die Anwesenheitskontrolle zu erhalten.", flash[:alert]
  end

  test "destroy ist für Trainer ohne Adminrechte gesperrt" do
    sign_out users(:admin)
    sign_in users(:one)
    future = training_sessions(:future)

    assert_no_difference("TrainingSession.count") do
      delete training_session_url(future)
    end
  end

  test "toggle_attendance: ohne Drop-in ist Teilnehmer standardmäßig anwesend, Klick markiert abwesend" do
    registration = course_registrations(:one)
    assert_not @training_session.course.has_ticketing?
    attendances(:one).destroy # Fixture-Datensatz entfernen: Test startet ohne Attendance-Record

    get training_session_url(@training_session)
    assert_match participants(:one).first_name, @response.body

    assert_difference("Attendance.count", 1) do
      post toggle_attendance_training_session_url(@training_session), params: { course_registration_id: registration.id }
    end
    attendance = @training_session.attendances.find_by(course_registration_id: registration.id)
    assert_equal "abwesend", attendance.status

    assert_difference("Attendance.count", -1) do
      post toggle_attendance_training_session_url(@training_session), params: { course_registration_id: registration.id }
    end
    assert_nil @training_session.attendances.find_by(course_registration_id: registration.id)
  end

  test "toggle_attendance: bei Drop-in-Kursen ist Teilnehmer standardmäßig abwesend, Klick markiert anwesend" do
    @training_session.course.update!(has_ticketing: true)
    registration = course_registrations(:one)
    attendances(:one).destroy # Fixture-Datensatz entfernen: Test startet ohne Attendance-Record

    assert_difference("Attendance.count", 1) do
      post toggle_attendance_training_session_url(@training_session), params: { course_registration_id: registration.id }
    end
    attendance = @training_session.attendances.find_by(course_registration_id: registration.id)
    assert_equal "anwesend", attendance.status

    assert_difference("Attendance.count", -1) do
      post toggle_attendance_training_session_url(@training_session), params: { course_registration_id: registration.id }
    end
    assert_nil @training_session.attendances.find_by(course_registration_id: registration.id)
  end

  test "confirm_attendance marks past session as confirmed" do
    @training_session.update!(attendance_confirmed_at: nil)

    post confirm_attendance_training_session_url(@training_session)

    assert_redirected_to training_session_url(@training_session)
    assert @training_session.reload.attendance_confirmed?
    assert_equal users(:admin), @training_session.attendance_confirmed_by
  end

  test "confirm_attendance is rejected for future session" do
    future = training_sessions(:future)

    post confirm_attendance_training_session_url(future)

    assert_redirected_to training_session_url(future)
    assert_not future.reload.attendance_confirmed?
  end

  test "reopen_attendance clears confirmation" do
    @training_session.confirm_attendance!(users(:admin))

    post reopen_attendance_training_session_url(@training_session)

    assert_redirected_to training_session_url(@training_session)
    assert_not @training_session.reload.attendance_confirmed?
  end

  test "scanner leitet zurück, wenn der Kurs kein Ticketing nutzt" do
    @training_session.course.update!(has_ticketing: false)

    get scanner_training_session_url(@training_session)

    assert_redirected_to training_session_url(@training_session)
    assert_equal I18n.t("training_sessions.show.scanner_not_available"), flash[:alert]
  end

  test "scanner ist erreichbar, wenn der Kurs Ticketing nutzt" do
    @training_session.course.update!(has_ticketing: true)

    get scanner_training_session_url(@training_session)

    assert_response :success
  end

  test "send_unsubscribe_reminder verschickt genau eine Mail und meldet Erfolg" do
    registration = course_registrations(:one)

    assert_enqueued_email_with TrainingSessionMailer, :unsubscribe_reminder,
      args: [ @training_session, registration ] do
      post send_unsubscribe_reminder_training_session_url(@training_session),
        params: { course_registration_id: registration.id }
    end

    assert_redirected_to training_session_url(@training_session)
    assert_equal I18n.t("training_sessions.show.reminder_sent", name: registration.participant.first_name), flash[:notice]
  end

  test "send_unsubscribe_reminder meldet Fehler bei ungültiger Anmeldung" do
    assert_no_enqueued_emails do
      post send_unsubscribe_reminder_training_session_url(@training_session),
        params: { course_registration_id: 0 }
    end

    assert_redirected_to training_session_url(@training_session)
    assert_equal I18n.t("training_sessions.show.reminder_invalid"), flash[:alert]
  end

  test "cancel verschickt Admin-Info nur an Admins, die sie nicht persönlich abgeschaltet haben" do
    opted_out = User.new(email: "opted-out-admin@example.com", admin: true, country: "CH",
      admin_notification_preferences: { "training_cancelled" => false })
    opted_out.password = "password123"
    opted_out.privacy_accepted = true
    opted_out.skip_confirmation!
    opted_out.save!(validate: false)

    assert_enqueued_email_with TrainingSessionMailer, :training_cancelled_admin_notice,
      args: [ @training_session, users(:admin) ] do
      post cancel_training_session_url(@training_session), params: { cancellation_reason: "Hallenausfall wegen Bauarbeiten" }
    end

    admin_notice_jobs = enqueued_jobs.select { |j| j[:args][0..1] == [ "TrainingSessionMailer", "training_cancelled_admin_notice" ] }
    assert_equal 1, admin_notice_jobs.size, "erwartet genau eine Admin-Info-Mail (nur an users(:admin), nicht an opted_out)"
  end

  test "cancel speichert den mitgegebenen Grund" do
    post cancel_training_session_url(@training_session), params: { cancellation_reason: "Hallenausfall wegen Bauarbeiten" }

    assert_equal "Hallenausfall wegen Bauarbeiten", @training_session.reload.cancellation_reason
  end

  test "cancel wird abgelehnt, wenn kein Grund angegeben wurde" do
    assert_no_enqueued_emails do
      post cancel_training_session_url(@training_session), params: { cancellation_reason: "   " }
    end

    @training_session.reload
    assert_not @training_session.is_canceled?
    assert_nil @training_session.cancellation_reason
    assert_equal I18n.t("training_sessions.show.cancel_reason_required"), flash[:alert]
  end

  test "cancellation_notice-Mail enthält den Grund" do
    @training_session.update_column(:cancellation_reason, "Krankheit der Trainerin")

    mail = TrainingSessionMailer.cancellation_notice(@training_session, users(:one))

    [ mail.text_part, mail.html_part ].each do |part|
      assert_match "Krankheit der Trainerin", part.body.decoded
    end
  end

  test "set_substitute: zugewiesener Trainer kann Ersatz eintragen, Mails an Ersatz und Admins werden verschickt" do
    sign_out users(:admin)
    sign_in users(:one) # trainers(:one) ist via course_trainers(:one) dem Kurs zugewiesen

    assert_enqueued_email_with TrainingSessionMailer, :substitute_assigned,
      args: [ @training_session, trainers(:two) ] do
      assert_enqueued_email_with TrainingSessionMailer, :substitute_assigned_admin_notice,
        args: [ @training_session, trainers(:two), users(:admin) ] do
        post set_substitute_training_session_url(@training_session),
          params: { substitute_trainer_id: trainers(:two).id, substitute_reason: "Bin krank" }
      end
    end

    @training_session.reload
    assert_equal trainers(:two), @training_session.substitute_trainer
    assert_equal "Bin krank", @training_session.substitute_reason
    assert_redirected_to training_session_url(@training_session)
  end

  test "set_substitute: fehlender Grund wird abgelehnt" do
    sign_out users(:admin)
    sign_in users(:one)

    assert_no_enqueued_emails do
      post set_substitute_training_session_url(@training_session),
        params: { substitute_trainer_id: trainers(:two).id, substitute_reason: "" }
    end

    assert_nil @training_session.reload.substitute_trainer
    assert_equal I18n.t("training_sessions.show.substitute_reason_required"), flash[:alert]
  end

  test "set_substitute: nicht zugewiesener Trainer wird abgewiesen" do
    sign_out users(:admin)
    sign_in users(:two) # trainers(:two) ist NICHT diesem Kurs zugewiesen

    assert_no_enqueued_emails do
      post set_substitute_training_session_url(@training_session),
        params: { substitute_trainer_id: trainers(:two).id, substitute_reason: "Bin krank" }
    end

    assert_nil @training_session.reload.substitute_trainer
    assert_equal I18n.t("training_sessions.show.substitute_not_authorized"), flash[:alert]
  end

  test "set_substitute: leerer Wert entfernt den eingetragenen Ersatz" do
    @training_session.update!(substitute_trainer: trainers(:two))

    post set_substitute_training_session_url(@training_session), params: { substitute_trainer_id: "" }

    assert_nil @training_session.reload.substitute_trainer
  end
end
