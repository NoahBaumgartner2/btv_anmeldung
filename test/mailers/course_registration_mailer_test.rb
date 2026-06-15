require "test_helper"

class CourseRegistrationMailerTest < ActionMailer::TestCase
  setup do
    @registration = course_registrations(:one)
    @participant  = @registration.participant
    @course       = @registration.course
    @recipient    = @participant.user
  end

  test "self_cancelled sends mail to participant's user" do
    mail = CourseRegistrationMailer.self_cancelled(@registration)

    assert_equal [ @recipient.email ], mail.to
    assert_match "Abmeldung bestätigt", mail.subject
    assert_match @course.title, mail.subject
  end

  test "self_cancelled body mentions participant and course" do
    mail = CourseRegistrationMailer.self_cancelled(@registration)

    assert_match @participant.first_name, mail.body.encoded
    assert_match @course.title, mail.body.encoded
  end

  test "self_cancelled nennt die Kursleitung als Kontakt, wenn Trainer zugewiesen sind" do
    trainer = @course.trainers.first
    assert trainer.present?, "Fixture-Kurs sollte mind. einen zugewiesenen Trainer haben"

    mail = CourseRegistrationMailer.self_cancelled(@registration)

    assert_match "Kursleitung", mail.body.encoded
    assert_match trainer.full_name, mail.body.encoded
  end

  test "self_cancelled fällt auf Vereinskontakt zurück, wenn keine Trainer zugewiesen sind" do
    @course.course_trainers.destroy_all

    mail = CourseRegistrationMailer.self_cancelled(@registration)

    assert_no_match "Kursleitung", mail.body.encoded
    assert_match "Bei Fragen wende dich bitte", mail.body.encoded
  end

  test "self_cancelled with refund shows refund amount" do
    mail = CourseRegistrationMailer.self_cancelled(@registration, refund_amount_cents: 5000)
    assert_match "50.00", mail.body.encoded
  end
end
