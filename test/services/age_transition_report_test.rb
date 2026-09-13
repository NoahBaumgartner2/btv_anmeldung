require "test_helper"

class AgeTransitionReportTest < ActiveSupport::TestCase
  def make_course(title:, term:, max_age:, start_date:, previous_course: nil)
    course = Course.new(title: title, registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      term: term, max_age: max_age, previous_course: previous_course)
    course.start_date = start_date
    course.end_date = start_date + 4.months
    course.save!(validate: false)
    course
  end

  def make_participant(first_name:, dob:)
    p = Participant.new(user: users(:one), first_name: first_name, last_name: "Test",
      date_of_birth: dob, gender: "weiblich", phone_number: "+41790000000")
    p.save!(validate: false)
    p
  end

  def enroll(course, participant, status: "bestätigt")
    reg = CourseRegistration.new(course: course, participant: participant, status: status)
    reg.save!(validate: false)
    reg
  end

  test "liefert leere Liste ohne Term" do
    assert_equal [], AgeTransitionReport.for(nil)
  end

  test "listet Personen, die im Nachfolgekurs das Höchstalter überschreiten" do
    alt = make_course(title: "Alt", term: terms(:one), max_age: 10, start_date: Date.new(2026, 8, 17))
    neu = make_course(title: "Neu", term: terms(:two), max_age: 10, start_date: Date.new(2027, 1, 11),
      previous_course: alt)

    # Wird am 11.1.2027 elf -> zu alt für "Neu", war am 17.8.2026 aber erst zehn.
    waechst_heraus = make_participant(first_name: "Waechst", dob: Date.new(2016, 1, 1))
    # Bleibt zehn -> weiterhin zulässig.
    bleibt_drin = make_participant(first_name: "Bleibt", dob: Date.new(2017, 6, 1))
    enroll(alt, waechst_heraus)
    enroll(alt, bleibt_drin)

    groups = AgeTransitionReport.for(terms(:two))
    assert_equal 1, groups.size

    group = groups.first
    assert_equal neu, group.course
    assert_equal alt, group.previous_course
    assert_equal [ waechst_heraus.id ], group.entries.map { |e| e.participant.id }

    entry = group.entries.first
    assert_equal 11, entry.age_at_reference
    assert_not entry.already_too_old, "war im Vorgängerkurs noch im Rahmen"
    assert_not entry.exempt?
  end

  test "markiert Personen, die schon im Vorgängerkurs zu alt waren" do
    alt = make_course(title: "Alt", term: terms(:one), max_age: 10, start_date: Date.new(2026, 8, 17))
    make_course(title: "Neu", term: terms(:two), max_age: 10, start_date: Date.new(2027, 1, 11),
      previous_course: alt)

    # Schon am 17.8.2026 zwölf -> war bereits zu alt.
    schon_zu_alt = make_participant(first_name: "Schon", dob: Date.new(2014, 1, 1))
    enroll(alt, schon_zu_alt)

    entry = AgeTransitionReport.for(terms(:two)).first.entries.first
    assert entry.already_too_old
  end

  test "stornierte Anmeldungen zählen nicht" do
    alt = make_course(title: "Alt", term: terms(:one), max_age: 10, start_date: Date.new(2026, 8, 17))
    make_course(title: "Neu", term: terms(:two), max_age: 10, start_date: Date.new(2027, 1, 11),
      previous_course: alt)

    enroll(alt, make_participant(first_name: "Storno", dob: Date.new(2014, 1, 1)), status: "storniert")

    assert_empty AgeTransitionReport.for(terms(:two))
  end

  test "Kurse ohne Höchstalter bleiben aussen vor" do
    alt = make_course(title: "Alt", term: terms(:one), max_age: nil, start_date: Date.new(2026, 8, 17))
    make_course(title: "Neu", term: terms(:two), max_age: nil, start_date: Date.new(2027, 1, 11),
      previous_course: alt)
    enroll(alt, make_participant(first_name: "Egal", dob: Date.new(2000, 1, 1)))

    assert_empty AgeTransitionReport.for(terms(:two))
  end

  test "ohne Vorgängerkurs wird der eigene Bestand geprüft und als bereits zu alt gewertet" do
    neu = make_course(title: "Solo", term: terms(:two), max_age: 10, start_date: Date.new(2027, 1, 11))
    zu_alt = make_participant(first_name: "Solo", dob: Date.new(2010, 1, 1))
    enroll(neu, zu_alt)

    entry = AgeTransitionReport.for(terms(:two)).first.entries.first
    assert_equal zu_alt, entry.participant
    assert entry.already_too_old
  end

  test "erteilte Altersausnahme wird im Eintrag ausgewiesen" do
    alt = make_course(title: "Alt", term: terms(:one), max_age: 10, start_date: Date.new(2026, 8, 17))
    neu = make_course(title: "Neu", term: terms(:two), max_age: 10, start_date: Date.new(2027, 1, 11),
      previous_course: alt)
    person = make_participant(first_name: "Ausnahme", dob: Date.new(2014, 1, 1))
    enroll(alt, person)
    AgeExemption.create!(participant: person, course: neu, note: "Darf fertig machen")

    entry = AgeTransitionReport.for(terms(:two)).first.entries.first
    assert entry.exempt?
    assert_equal "Darf fertig machen", entry.exemption.note
  end

  # ── .termless (Kurse ohne Zeitraum, z.B. Krabbelgym) ─────────────────────────

  test "termless findet Personen, die HEUTE in einem termlosen Kurs zu alt sind" do
    krabbel = make_course(title: "Krabbelgym", term: nil, max_age: 4, start_date: 1.year.ago.to_date)
    zu_alt = make_participant(first_name: "Krabbel", dob: 5.years.ago.to_date - 1.month)
    passt = make_participant(first_name: "Passt", dob: 3.years.ago.to_date)
    enroll(krabbel, zu_alt)
    enroll(krabbel, passt)

    groups = AgeTransitionReport.termless
    assert_equal 1, groups.size
    group = groups.first
    assert_equal krabbel, group.course
    assert group.continuous?
    assert_nil group.previous_course
    assert_equal [ zu_alt.id ], group.entries.map { |e| e.participant.id }
    assert group.entries.first.already_too_old
  end

  test "termless ignoriert Kurse, die einen Term haben" do
    mit_term = make_course(title: "Mit Term", term: terms(:one), max_age: 4, start_date: Date.new(2026, 8, 17))
    enroll(mit_term, make_participant(first_name: "Alt", dob: Date.new(2000, 1, 1)))

    assert_empty AgeTransitionReport.termless
  end

  test "termless respektiert Altersausnahmen" do
    krabbel = make_course(title: "Krabbelgym", term: nil, max_age: 4, start_date: 1.year.ago.to_date)
    zu_alt = make_participant(first_name: "Krabbel", dob: 5.years.ago.to_date - 1.month)
    enroll(krabbel, zu_alt)
    AgeExemption.create!(participant: zu_alt, course: krabbel)

    entry = AgeTransitionReport.termless.first.entries.first
    assert entry.exempt?
  end
end
