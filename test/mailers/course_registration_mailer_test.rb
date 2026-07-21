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

  test "confirmation Schnupper-Mail nennt Kursleitung mit Name und E-Mail" do
    trainer = @course.trainers.first
    assert trainer.present?, "Fixture-Kurs sollte mind. einen zugewiesenen Trainer haben"
    @registration.update_column(:status, "schnuppern")

    mail = CourseRegistrationMailer.confirmation(@registration)

    [ mail.text_part, mail.html_part ].each do |part|
      assert_match "Kontakt zur Kursleitung", part.body.decoded
      assert_match trainer.full_name, part.body.decoded
      assert_match trainer.user.email, part.body.decoded
    end
  end

  test "confirmation zeigt Kursleitungs-Kontakt NICHT bei bestätigter Anmeldung" do
    @registration.update_column(:status, "bestätigt")

    mail = CourseRegistrationMailer.confirmation(@registration)

    assert_no_match "Kontakt zur Kursleitung", mail.text_part.body.decoded
    assert_no_match "Kontakt zur Kursleitung", mail.html_part.body.decoded
  end

  test "confirmation zeigt email_note in Text- und HTML-Version wenn gesetzt" do
    @course.update!(email_note: "Türcode 1234")

    mail = CourseRegistrationMailer.confirmation(@registration)

    [ mail.text_part, mail.html_part ].each do |part|
      assert_match "Zusätzliche Informationen", part.body.decoded
      assert_match "Türcode 1234", part.body.decoded
    end
  end

  test "confirmation zeigt keinen Zusatzinfo-Block wenn email_note leer ist" do
    @course.update!(email_note: nil)

    mail = CourseRegistrationMailer.confirmation(@registration)

    assert_no_match "Zusätzliche Informationen", mail.text_part.body.decoded
    assert_no_match "Zusätzliche Informationen", mail.html_part.body.decoded
  end

  test "confirmation escaped HTML im email_note (kein raw)" do
    @course.update!(email_note: "<b>fett</b>")

    mail = CourseRegistrationMailer.confirmation(@registration)

    assert_match "&lt;b&gt;fett&lt;/b&gt;", mail.html_part.body.decoded
    assert_no_match "<b>fett</b>", mail.html_part.body.decoded
  end

  test "greeting_name nutzt first_name des Empfängers" do
    @recipient.update!(first_name: "Lena")

    mail = CourseRegistrationMailer.confirmation(@registration)

    assert_match "Hallo Lena", mail.body.encoded
  end

  test "greeting_name fällt auf Trainer-Vorname zurück wenn first_name leer" do
    assert_nil @recipient.first_name
    assert_equal "Anna", @recipient.trainer.first_name

    mail = CourseRegistrationMailer.confirmation(@registration)

    assert_match "Hallo Anna", mail.body.encoded
  end

  test "greeting_name fällt auf E-Mail-Präfix zurück wenn kein Name und kein Trainer" do
    user = users(:parent_only)
    assert_nil user.first_name
    assert_nil user.trainer

    participant = participants(:parent_only_child)
    reg = CourseRegistration.new(course: @course, participant: participant, status: "bestätigt")
    reg.save!(validate: false)

    mail = CourseRegistrationMailer.confirmation(reg)

    assert_match "Hallo parent_only", mail.body.encoded
  end

  test "payment_receipt zeigt den tatsächlich gezahlten Betrag (mit Rabatt), nicht den Kurspreis" do
    @course.update!(has_payment: true, price_cents: 15000)
    # Kind hat dank Rabatt nur CHF 120 gezahlt (applied_price_cents)
    @registration.update_columns(applied_price_cents: 12000, applied_discount: "sibling")

    mail = CourseRegistrationMailer.payment_receipt(@registration)

    assert_match "CHF 120.00", mail.body.encoded
    assert_no_match(/CHF 150\.00/, mail.body.encoded)
  end

  test "payment_receipt fällt auf den Kurspreis zurück, wenn kein Rabatt angewandt wurde" do
    @course.update!(has_payment: true, price_cents: 15000)
    @registration.update_columns(applied_price_cents: nil, applied_discount: nil)

    mail = CourseRegistrationMailer.payment_receipt(@registration)

    assert_match "CHF 150.00", mail.body.encoded
  end

  test "trial_expired rendert und nennt Teilnehmer, Kurs und Schnupper-Bezug" do
    @registration.update_columns(status: "schnuppern")

    mail = CourseRegistrationMailer.trial_expired(@registration)

    assert_equal [ @recipient.email ], mail.to
    assert_match "Reservierung abgelaufen", mail.subject
    assert_match @course.title, mail.subject
    body = mail.body.encoded
    assert_match @participant.first_name, body
    assert_match @course.title, body
    assert_match(/Schnupper/, body, "trial_expired-Mail muss den Schnupper-Bezug erwähnen")
  end

  test "payment_expired wird für Schnupperplätze nicht verschickt (trial_expired ist zuständig)" do
    @registration.update_columns(status: "schnuppern")

    assert_no_emails do
      CourseRegistrationMailer.payment_expired(@registration).deliver_now
    end
  end

  # ── confirmation: kein falscher Warteliste-Text für ausstehend/platz_frei ───
  test "confirmation wird für ausstehend NICHT verschickt (kein falscher Warteliste-Text)" do
    @registration.update_column(:status, "ausstehend")

    assert_no_emails do
      CourseRegistrationMailer.confirmation(@registration).deliver_now
    end
  end

  test "confirmation wird für platz_frei NICHT verschickt (waitlist_promoted ist zuständig)" do
    @registration.update_column(:status, "platz_frei")

    assert_no_emails do
      CourseRegistrationMailer.confirmation(@registration).deliver_now
    end
  end

  test "confirmation zeigt den Warteliste-Text nur bei Status warteliste" do
    @registration.update_column(:status, "warteliste")

    mail = CourseRegistrationMailer.confirmation(@registration)

    assert_match "Auf der Warteliste", mail.subject
    assert_match "Warteliste", mail.html_part.body.decoded
    assert_match "Warteliste", mail.text_part.body.decoded
  end

  test "confirmation bei bestätigt enthält keinen Warteliste-Text" do
    @registration.update_column(:status, "bestätigt")

    mail = CourseRegistrationMailer.confirmation(@registration)

    assert_match "Anmeldung bestätigt", mail.subject
    assert_no_match "Warteliste", mail.html_part.body.decoded
    assert_no_match "Warteliste", mail.text_part.body.decoded
  end

  test "confirmation nutzt bei bestätigtem Abo die eigenständige Abo-Vorlage statt der generischen" do
    @course.update_columns(registration_mode: "abo", registration_type: "abo", abo_size: 10)
    @registration.update_columns(status: "bestätigt", abo_entries_total: 10, abo_entries_used: 3)

    mail = CourseRegistrationMailer.confirmation(@registration)

    assert_match "Abo aktiviert", mail.subject
    [ mail.text_part, mail.html_part ].each do |part|
      body = part.body.decoded
      assert_match "Buchungsseite", body
      assert_match "7", body # verbleibende Eintritte (10 - 3)
      assert_no_match "abzumelden", body
    end
  end

  test "confirmation zeigt für Abo mit Status warteliste weiterhin die generische Vorlage" do
    @course.update_columns(registration_mode: "abo", registration_type: "abo", abo_size: 10)
    @registration.update_column(:status, "warteliste")

    mail = CourseRegistrationMailer.confirmation(@registration)

    assert_match "Auf der Warteliste", mail.subject
  end
end
