require "test_helper"

# Mehrere Trainer: Training nur für ausgewählte Teilnehmende absagen.
class TrainingPartialCancelTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @course = Course.new(title: "Zwei Trainer", registration_type: "quartal", registration_mode: "quartal",
      has_payment: true, price_cents: 15_000, training_value_cents: 2500, has_ticketing: false, allows_holiday_deduction: false)
    @course.save!(validate: false)
    CourseTrainer.without_assignment_notifications { @course.trainers << Trainer.limit(2).to_a }
    @session = @course.training_sessions.create!(start_time: 1.week.from_now, end_time: 1.week.from_now + 1.hour)
    @one = enroll(participants(:one))
    @two = enroll(participants(:two))
    sign_in users(:admin)
    clear_enqueued_jobs
  end

  def enroll(participant)
    CourseRegistration.new(course: @course, participant: participant, status: "bestätigt", payment_cleared: true,
      created_at: 1.month.ago, holiday_deduction_claimed: false).tap { |r| r.save!(validate: false) }
  end

  def notices = enqueued_jobs.select { |job| job["arguments"].first(2) == [ "TrainingSessionMailer", "cancellation_notice" ] }

  def cancel(params) = post(cancel_training_session_path(@session), params: { cancellation_reason: "Halle halb belegt", **params })

  test "nur die Ausgewählten sind abgesagt und bekommen eine Mail, das Training bleibt aktiv" do
    cancel(cancel_scope: "selected", course_registration_ids: [ @one.id ])

    assert_not @session.reload.is_canceled?
    attendance = @session.attendances.find_by(course_registration: @one)
    assert_equal "abgemeldet", attendance.status
    assert_equal "Halle halb belegt", attendance.cancellation_reason
    assert_nil @session.attendances.find_by(course_registration: @two)
    assert_equal 1, notices.size

    perform_enqueued_jobs
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ @one.participant.user.email ], mail.to
    assert_includes mail.text_part.body.decoded, @one.participant.first_name
    assert_includes mail.text_part.body.decoded, "Halle halb belegt"
  end

  test "ohne Auswahl passiert nichts" do
    cancel(cancel_scope: "selected")

    assert_match "mindestens", flash[:alert]
    assert_not @session.reload.is_canceled?
    assert_empty @session.attendances
  end

  test "fremde Anmeldung wird ignoriert" do
    other_course = Course.new(title: "Anderer Kurs", registration_type: "quartal", registration_mode: "quartal",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    other_course.save!(validate: false)
    foreign = CourseRegistration.new(course: other_course, participant: participants(:one), status: "bestätigt", holiday_deduction_claimed: false)
    foreign.save!(validate: false)

    cancel(cancel_scope: "selected", course_registration_ids: [ foreign.id, @one.id ])

    assert_equal [ @one.id ], @session.attendances.pluck(:course_registration_id)
  end

  test "alle ausgewählt: ganzes Training abgesagt" do
    cancel(cancel_scope: "selected", course_registration_ids: [ @one.id, @two.id ])

    assert @session.reload.is_canceled?
    assert_empty @session.attendances
  end

  test "ohne E-Mail-Auswahl geht keine Mail raus" do
    cancel(cancel_scope: "selected", course_registration_ids: [ @one.id ], send_mail: "0")

    assert_equal 1, @session.attendances.count
    assert_equal 0, notices.size
  end

  test "bei nur einem Trainer gibt es keine Teilabsage" do
    @course.course_trainers.last.delete

    get training_session_path(@session)
    assert_select "input[name=cancel_scope]", count: 0

    cancel(cancel_scope: "selected", course_registration_ids: [ @one.id ])
    assert @session.reload.is_canceled?
  end

  test "Overlay zeigt die Auswahl, Admin kann die Absage aufheben" do
    get training_session_path(@session)
    assert_select "input[name=cancel_scope][value=selected]"
    assert_select "input[name='course_registration_ids[]']", count: 2

    cancel(cancel_scope: "selected", course_registration_ids: [ @one.id ])
    get training_session_path(@session)
    assert_select "input[name='course_registration_ids[]']", count: 1
    assert_match "Absage aufheben", response.body

    post uncancel_training_session_path(@session, course_registration_id: @one.id)
    assert_empty @session.attendances
    assert_not @session.reload.is_canceled?
  end

  test "abgesagtes Training zählt nicht für die Rückerstattung, und abgesagte Personen können sich nicht wieder anmelden" do
    @session.update_columns(start_time: 1.week.ago, end_time: 1.week.ago + 1.hour)
    second = @course.training_sessions.create!(start_time: 2.weeks.ago, end_time: 2.weeks.ago + 1.hour)
    assert_equal 2, RefundService.attended_sessions_count(@one)

    second.attendances.create!(course_registration: @one, status: "abgemeldet", cancellation_reason: "Halle")
    assert_equal 1, RefundService.attended_sessions_count(@one.reload)
    assert_equal 2, RefundService.attended_sessions_count(@two)

    future = @course.training_sessions.create!(start_time: 1.week.from_now, end_time: 1.week.from_now + 1.hour)
    attendance = future.attendances.create!(course_registration: @one, status: "abgemeldet", cancellation_reason: "Halle")
    post resubscribe_to_session_course_registration_path(@one), params: { training_session_id: future.id }
    assert Attendance.exists?(attendance.id)
  end
end
