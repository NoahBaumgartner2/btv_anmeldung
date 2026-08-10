require "test_helper"

class TrainingSessionMailerTest < ActionMailer::TestCase
  setup do
    @training_session = training_sessions(:one)
    @registration     = course_registrations(:one)
    @participant      = @registration.participant
    @course           = @registration.course
    @recipient        = @participant.user
  end

  test "unsubscribe_reminder geht an den User der teilnehmenden Person" do
    mail = TrainingSessionMailer.unsubscribe_reminder(@training_session, @registration)

    assert_equal [ @recipient.email ], mail.to
    assert_match @participant.first_name, mail.subject
    assert_match @participant.last_name, mail.subject
    assert_match @course.title, mail.subject
  end

  test "unsubscribe_reminder nennt Trainer-E-Mails statt Selbst-Abmeldung in der App" do
    trainer = @course.trainers.first
    assert trainer&.user&.email.present?, "Fixture-Kurs sollte einen Trainer mit E-Mail haben"

    mail = TrainingSessionMailer.unsubscribe_reminder(@training_session, @registration)

    assert_match trainer.user.email, mail.body.encoded
    assert_no_match(/Mein Profil/, mail.body.encoded)
  end
end
