require "test_helper"

# Auswahl "E-Mail senden": Standard ist senden, abgewählt (send_mail=0) geht keine Mail
# an die betroffene Person.
class SendMailChoiceTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @course = Course.new(title: "Mailkurs", registration_type: "quartal", registration_mode: "quartal",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    @course.save!(validate: false)
    @registration = CourseRegistration.new(course: @course, participant: participants(:one), status: "bestätigt",
      holiday_deduction_claimed: false)
    @registration.save!(validate: false)
    sign_in users(:admin)
    clear_enqueued_jobs
  end

  def mails(mailer, action)
    enqueued_jobs.count { |job| job["arguments"].first(2) == [ mailer, action ] }
  end

  test "Abmelden durch Trainer: Standard sendet, abgewählt nicht, Admin-Hinweis bleibt" do
    post trainer_cancel_course_registration_path(@registration), params: { send_mail: "0" }

    assert_equal "storniert", @registration.reload.status
    assert_equal 0, mails("CourseRegistrationMailer", "cancelled_by_trainer")
    assert_operator mails("CourseRegistrationMailer", "admin_refund_done_notice"), :>=, 1

    @registration.update_columns(status: "bestätigt")
    post trainer_cancel_course_registration_path(@registration)
    assert_equal 1, mails("CourseRegistrationMailer", "cancelled_by_trainer")
  end

  test "Training absagen" do
    session = @course.training_sessions.create!(start_time: 1.week.from_now, end_time: 1.week.from_now + 1.hour)

    post cancel_training_session_path(session), params: { cancellation_reason: "Halle zu", send_mail: "0" }

    assert session.reload.is_canceled?
    assert_equal 0, mails("TrainingSessionMailer", "cancellation_notice")
    assert_match "nicht per E-Mail", flash[:notice]

    session.update_columns(is_canceled: false)
    post cancel_training_session_path(session), params: { cancellation_reason: "Halle zu", send_mail: "1" }
    assert_equal 1, mails("TrainingSessionMailer", "cancellation_notice")
  end

  test "Manuelle Anmeldung ohne Mail, auch nicht das Passwort-Mail einer neuen Familie" do
    post manual_enroll_course_path(@course), params: { participant_id: participants(:two).id, send_mail: "0" }
    assert @course.course_registrations.exists?(participant: participants(:two))
    assert_equal 0, mails("CourseRegistrationMailer", "confirmation")

    assert_no_emails do
      post manual_enroll_course_path(@course), params: {
        new_family_email: "neu-#{SecureRandom.hex(3)}@example.com", email_only: "true", send_mail: "0",
        participant: { first_name: "Nora", last_name: "Neu" }
      }
    end
    assert_equal 0, mails("ParticipantMailer", "complete_profile")
    assert_equal 0, enqueued_jobs.count { |job| job["arguments"].first == "Devise::Mailer" }
    assert @course.course_registrations.joins(:participant).exists?(participants: { first_name: "Nora" })
  end

  test "Trainer einem Kurs zuweisen: Zuweisungs-Mail nur mit Auswahl, Schalter danach wieder frei" do
    trainer = trainers(:one)

    post update_courses_trainer_path(trainer), params: { send_mail: "0", trainer: { course_ids: trainer.course_ids + [ @course.id ] } }
    assert_includes trainer.reload.course_ids, @course.id
    assert_equal 0, mails("CourseTrainerMailer", "assigned_to_course")
    assert_not CourseTrainer.skip_assignment_notification

    other = Course.new(title: "Mailkurs 2", registration_type: "quartal", registration_mode: "quartal",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    other.save!(validate: false)
    post update_courses_trainer_path(trainer), params: { trainer: { course_ids: trainer.reload.course_ids + [ other.id ] } }
    assert_equal 1, mails("CourseTrainerMailer", "assigned_to_course")
  end

  test "Nachforderung ohne Mail wird trotzdem erstellt" do
    assert_difference "SupplementaryCharge.count", 1 do
      post admin_supplementary_charges_path, params: {
        course_id: @course.id, participant_ids: [ participants(:one).id ],
        amount: "30", description: "Korrektur", send_mail: "0"
      }
    end
    assert_equal 0, mails("SupplementaryChargeMailer", "payment_request")
  end

  test "Formulare zeigen die Auswahl standardmässig angehakt" do
    get manage_course_path(@course)
    assert_response :success
    assert_select "input[type=checkbox][name=send_mail][checked]", minimum: 2
    assert_select "input[type=hidden][name=send_mail][value='0']", minimum: 2
    assert_select "input[type=checkbox][name=send_mail][form=manual-enroll-form]"
  end

  test "Verlängerung: Knopf ohne Mail informiert niemanden, Standard (auch Job) schon" do
    terms(:two).update!(priority_registration_date: Date.new(2026, 12, 22))
    @course.update_columns(term_id: terms(:one).id, auto_rollover: false)

    travel_to(Date.new(2026, 12, 22)) do
      post roll_over_course_path(@course), params: { send_mail: "0" }
      assert @course.reload.next_course
      assert_equal 0, mails("CourseRegistrationMailer", "renewal_available")

      @course.next_course.destroy!
      @course.update_columns(rollover_notified_at: nil)
      assert CourseRolloverService.roll_over!(@course.reload)
      assert_equal 1, mails("CourseRegistrationMailer", "renewal_available")
    end
  end

  test "alle übrigen Formulare zeigen die Auswahl" do
    session = @course.training_sessions.create!(start_time: 1.week.from_now, end_time: 1.week.from_now + 1.hour)

    [ training_session_path(session), new_admin_supplementary_charge_path, trainer_path(trainers(:one)),
      edit_course_path(@course), new_trainer_path(tab: "invite") ].each do |path|
      get path
      assert_response :success, path
      assert_select "input[type=checkbox][name=send_mail][checked]", { minimum: 1 }, path
    end
  end
end
