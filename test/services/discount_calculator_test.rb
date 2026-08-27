require "test_helper"

class DiscountCalculatorTest < ActiveSupport::TestCase
  # ── Setup-Helfer ─────────────────────────────────────────────────────────────

  def make_course(title: "Rabatt-Kurs", category: "polysport", price: 10_000,
                  discounts: true, sibling: 6_000, second: 7_000,
                  youth: nil, youth_max_age: 20,
                  training_value: nil, allows_late_registration_deduction: true)
    course = Course.new(title: title, registration_type: "semester",
      has_payment: true, has_ticketing: false, allows_holiday_deduction: false,
      category: category)
    course.price_cents = price
    course.discounts_enabled = discounts
    course.sibling_price_cents = sibling
    course.second_course_price_cents = second
    course.youth_price_cents = youth
    course.youth_max_age = youth_max_age
    course.training_value_cents = training_value
    course.allows_late_registration_deduction = allows_late_registration_deduction
    course.save!(validate: false)
    course
  end

  def make_participant(user, first_name:, last_name: "Kind", dob: Date.new(2014, 1, 1), ahv: nil)
    participant = Participant.new(user: user, first_name: first_name, last_name: last_name,
      date_of_birth: dob, gender: "weiblich", phone_number: "+41790000000", ahv_number: ahv)
    participant.save!(validate: false)
    participant
  end

  def make_registration(course, participant, status: "ausstehend", payment_cleared: false, created_at: Time.current)
    reg = CourseRegistration.new(course: course, participant: participant,
      status: status, payment_cleared: payment_cleared, holiday_deduction_claimed: false)
    reg.save!(validate: false)
    reg.update_column(:created_at, created_at)
    reg
  end

  def make_session(course, start_time:, canceled: false)
    course.training_sessions.create!(start_time: start_time, end_time: start_time + 1.hour, is_canceled: canceled)
  end

  # ── Grundfälle ───────────────────────────────────────────────────────────────

  test "voller Preis wenn Rabatte nicht aktiviert" do
    course = make_course(discounts: false)
    child  = make_participant(users(:one), first_name: "Anna")
    sibling = make_participant(users(:one), first_name: "Ben")
    make_registration(course, sibling, status: "bestätigt")

    result = DiscountCalculator.call(make_registration(course, child))
    assert_equal 10_000, result[:price_cents]
    assert_nil result[:discount]
  end

  test "voller Preis wenn Kurs keine Kategorie hat" do
    course = make_course(category: nil)
    child  = make_participant(users(:one), first_name: "Anna")
    sibling = make_participant(users(:one), first_name: "Ben")
    make_registration(course, sibling, status: "bestätigt")

    result = DiscountCalculator.call(make_registration(course, child))
    assert_equal 10_000, result[:price_cents]
    assert_nil result[:discount]
  end

  # ── Geschwister-Rabatt ───────────────────────────────────────────────────────

  test "sibling-Rabatt für zweites Kind desselben Kontos in gleicher Kategorie" do
    course  = make_course
    child   = make_participant(users(:one), first_name: "Anna")
    sibling = make_participant(users(:one), first_name: "Ben")
    make_registration(course, sibling, status: "bestätigt")

    result = DiscountCalculator.call(make_registration(course, child))
    assert_equal 6_000, result[:price_cents]
    assert_equal "sibling", result[:discount]
  end

  test "nur das später angemeldete Geschwisterkind bekommt den Rabatt, nicht beide" do
    course = make_course
    first_child  = make_participant(users(:one), first_name: "Anna")
    second_child = make_participant(users(:one), first_name: "Ben")
    first_reg  = make_registration(course, first_child, status: "bestätigt")
    second_reg = make_registration(course, second_child, status: "bestätigt")

    first_result  = DiscountCalculator.call(first_reg)
    second_result = DiscountCalculator.call(second_reg)

    assert_equal 10_000, first_result[:price_cents]
    assert_nil first_result[:discount]
    assert_equal 6_000, second_result[:price_cents]
    assert_equal "sibling", second_result[:discount]
  end

  test "kein Rabatt wenn bestehende Anmeldung in anderer Kategorie" do
    other_course = make_course(title: "Tennis", category: "tennis")
    course       = make_course(title: "Polysport", category: "polysport")
    child   = make_participant(users(:one), first_name: "Anna")
    sibling = make_participant(users(:one), first_name: "Ben")
    make_registration(other_course, sibling, status: "bestätigt")

    result = DiscountCalculator.call(make_registration(course, child))
    assert_equal 10_000, result[:price_cents]
    assert_nil result[:discount]
  end

  # ── Zweitkurs-Rabatt ─────────────────────────────────────────────────────────

  test "second_course-Rabatt wenn gleicher Participant anderen Kurs derselben Kategorie besucht" do
    course_a = make_course(title: "Kurs A")
    course_b = make_course(title: "Kurs B")
    child = make_participant(users(:one), first_name: "Anna")
    make_registration(course_a, child, status: "bestätigt")

    result = DiscountCalculator.call(make_registration(course_b, child))
    assert_equal 7_000, result[:price_cents]
    assert_equal "second_course", result[:discount]
  end

  test "second_course-Rabatt via AHV-Match über fremdes Konto" do
    course_a = make_course(title: "Kurs A")
    course_b = make_course(title: "Kurs B")
    identity_a = make_participant(users(:one), first_name: "Anna", ahv: "756.1111.2222.33")
    identity_b = make_participant(users(:two), first_name: "Anna-Lena", last_name: "Anders",
      dob: Date.new(2013, 5, 5), ahv: "7561111222233")
    make_registration(course_a, identity_a, status: "bestätigt")

    result = DiscountCalculator.call(make_registration(course_b, identity_b))
    assert_equal 7_000, result[:price_cents]
    assert_equal "second_course", result[:discount]
  end

  test "second_course-Rabatt via Name+Geburtsdatum-Match über fremdes Konto" do
    course_a = make_course(title: "Kurs A")
    course_b = make_course(title: "Kurs B")
    identity_a = make_participant(users(:one), first_name: "Mia", last_name: "Muster", dob: Date.new(2015, 3, 3))
    identity_b = make_participant(users(:two), first_name: " mia ", last_name: "MUSTER", dob: Date.new(2015, 3, 3))
    make_registration(course_a, identity_a, status: "bestätigt")

    result = DiscountCalculator.call(make_registration(course_b, identity_b))
    assert_equal 7_000, result[:price_cents]
    assert_equal "second_course", result[:discount]
  end

  # ── Kombination ──────────────────────────────────────────────────────────────

  test "bei beiden Rabatten gewinnt der günstigere Preis" do
    # second_course (5'000) ist günstiger als sibling (6'000)
    course_a = make_course(title: "Kurs A", sibling: 6_000, second: 5_000)
    course_b = make_course(title: "Kurs B", sibling: 6_000, second: 5_000)
    child   = make_participant(users(:one), first_name: "Anna")
    sibling = make_participant(users(:one), first_name: "Ben")
    make_registration(course_b, sibling, status: "bestätigt")
    make_registration(course_a, child, status: "bestätigt")

    result = DiscountCalculator.call(make_registration(course_b, child))
    assert_equal 5_000, result[:price_cents]
    assert_equal "second_course", result[:discount]
  end

  # ── Jugendpreis (altersbasiert) ──────────────────────────────────────────────

  test "Jugendlicher erhält den Jugendpreis beim ersten Training" do
    course = make_course(price: 30_000, youth: 25_000, youth_max_age: 20)
    child  = make_participant(users(:one), first_name: "Jana", dob: Date.new(2010, 1, 1))

    result = DiscountCalculator.call(make_registration(course, child))
    assert_equal 25_000, result[:price_cents]
    assert_equal "youth", result[:discount]
  end

  test "Jugendpreis greift unabhängig von discounts_enabled" do
    course = make_course(price: 30_000, youth: 25_000, discounts: false)
    child  = make_participant(users(:one), first_name: "Jana", dob: Date.new(2010, 1, 1))

    result = DiscountCalculator.call(make_registration(course, child))
    assert_equal 25_000, result[:price_cents]
    assert_equal "youth", result[:discount]
  end

  test "Erwachsener (Alter über youth_max_age) erhält keinen Jugendpreis" do
    course = make_course(price: 30_000, youth: 25_000, youth_max_age: 20)
    adult  = make_participant(users(:one), first_name: "Petra", dob: Date.new(1980, 1, 1))

    result = DiscountCalculator.call(make_registration(course, adult))
    assert_equal 30_000, result[:price_cents]
    assert_nil result[:discount]
  end

  test "Teilnehmer ohne Geburtsdatum erhält keinen Jugendpreis" do
    course = make_course(price: 30_000, youth: 25_000)
    child  = make_participant(users(:one), first_name: "Ohne", dob: nil)

    result = DiscountCalculator.call(make_registration(course, child))
    assert_equal 30_000, result[:price_cents]
    assert_nil result[:discount]
  end

  test "günstigerer Zweitkurs-Preis gewinnt für Jugendlichen über den Jugendpreis" do
    # Jugendpreis 250, Zweitkurs 200 → der günstigere Zweitkurs gewinnt (kein Stacking)
    course_a = make_course(title: "Pilates A", price: 30_000, youth: 25_000, second: 20_000)
    course_b = make_course(title: "Pilates B", price: 30_000, youth: 25_000, second: 20_000)
    child    = make_participant(users(:one), first_name: "Jana", dob: Date.new(2010, 1, 1))
    make_registration(course_a, child, status: "bestätigt")

    result = DiscountCalculator.call(make_registration(course_b, child))
    assert_equal 20_000, result[:price_cents]
    assert_equal "second_course", result[:discount]
  end

  # ── Welche bestehenden Anmeldungen zählen ────────────────────────────────────

  test "ausstehende unbezahlte Anmeldung zählt nicht als bestehende Anmeldung" do
    course  = make_course
    child   = make_participant(users(:one), first_name: "Anna")
    sibling = make_participant(users(:one), first_name: "Ben")
    make_registration(course, sibling, status: "ausstehend", payment_cleared: false)

    result = DiscountCalculator.call(make_registration(course, child))
    assert_equal 10_000, result[:price_cents]
    assert_nil result[:discount]
  end

  test "stornierte Anmeldung zählt nicht – auch wenn bezahlt" do
    course  = make_course
    child   = make_participant(users(:one), first_name: "Anna")
    sibling = make_participant(users(:one), first_name: "Ben")
    make_registration(course, sibling, status: "storniert", payment_cleared: true)

    result = DiscountCalculator.call(make_registration(course, child))
    assert_equal 10_000, result[:price_cents]
    assert_nil result[:discount]
  end

  test "ausstehende bezahlte Anmeldung zählt als bestehende Anmeldung" do
    course  = make_course
    child   = make_participant(users(:one), first_name: "Anna")
    sibling = make_participant(users(:one), first_name: "Ben")
    make_registration(course, sibling, status: "ausstehend", payment_cleared: true)

    result = DiscountCalculator.call(make_registration(course, child))
    assert_equal 6_000, result[:price_cents]
    assert_equal "sibling", result[:discount]
  end

  # ── Schnuppertraining verbraucht → nur noch verbleibende Trainings ───────────

  test "nach verbrauchtem Schnuppertraining zählt nur der Preis der verbleibenden Trainings" do
    course = make_course(discounts: false, training_value: 1_000)
    child  = make_participant(users(:one), first_name: "Anna")
    trial_session = make_session(course, start_time: 3.days.ago)
    make_session(course, start_time: 2.days.from_now)
    make_session(course, start_time: 9.days.from_now)

    reg = CourseRegistration.new(course: course, participant: child, status: "schnuppern",
      trial_session: trial_session, holiday_deduction_claimed: false)
    reg.save!(validate: false)

    result = DiscountCalculator.call(reg)
    assert_equal 2_000, result[:price_cents] # 2 verbleibende Trainings * 1'000, kein Freitraining mehr
    assert_equal "trial_remaining", result[:discount]
  end

  test "noch bevorstehendes Schnuppertraining bekommt weiterhin den vollen Preis" do
    course = make_course(discounts: false, training_value: 1_000)
    child  = make_participant(users(:one), first_name: "Anna")
    trial_session = make_session(course, start_time: 2.days.from_now)

    reg = CourseRegistration.new(course: course, participant: child, status: "schnuppern",
      trial_session: trial_session, holiday_deduction_claimed: false)
    reg.save!(validate: false)

    result = DiscountCalculator.call(reg)
    assert_equal 10_000, result[:price_cents]
    assert_nil result[:discount]
  end

  # ── Späteres Anmelden (Preisreduktion) ───────────────────────────────────────

  test "ein bereits stattgefundenes Training reduziert den Preis (kurzer Kurs, Fenster ab erstem Training)" do
    # Rabattfenster = 10'000 / 1'000 + 1 = 11 Trainings. Der Kurs hat nur 1 Training,
    # das Fenster beginnt also beim ersten und einzigen Training.
    course = make_course(discounts: false, training_value: 1_000)
    child  = make_participant(users(:one), first_name: "Anna")
    make_session(course, start_time: 3.days.ago)

    result = DiscountCalculator.call(make_registration(course, child))
    assert_equal 9_000, result[:price_cents]
    assert_equal "late_registration", result[:discount]
  end

  test "jedes vergangene Training im Rabattfenster wird abgezogen" do
    # Rabattfenster = 11 Trainings, Kurs hat nur 3 - das ganze Fenster deckt den
    # ganzen Kurs ab. Beide vergangenen Trainings zählen voll, das zukünftige nicht.
    course = make_course(discounts: false, training_value: 1_000)
    child  = make_participant(users(:one), first_name: "Anna")
    make_session(course, start_time: 10.days.ago)
    make_session(course, start_time: 3.days.ago)
    make_session(course, start_time: 2.days.from_now) # noch nicht stattgefunden - zählt nicht

    result = DiscountCalculator.call(make_registration(course, child))
    assert_equal 8_000, result[:price_cents] # 10'000 - 2 * 1'000
    assert_equal "late_registration", result[:discount]
  end

  test "abgesagte Trainings zählen nicht bei der Preisreduktion" do
    course = make_course(discounts: false, training_value: 1_000)
    child  = make_participant(users(:one), first_name: "Anna")
    make_session(course, start_time: 10.days.ago)
    make_session(course, start_time: 5.days.ago, canceled: true)
    make_session(course, start_time: 3.days.ago)

    result = DiscountCalculator.call(make_registration(course, child))
    assert_equal 8_000, result[:price_cents]
    assert_equal "late_registration", result[:discount]
  end

  test "keine Preisreduktion wenn allows_late_registration_deduction deaktiviert" do
    course = make_course(discounts: false, training_value: 1_000, allows_late_registration_deduction: false)
    child  = make_participant(users(:one), first_name: "Anna")
    make_session(course, start_time: 10.days.ago)
    make_session(course, start_time: 3.days.ago)

    result = DiscountCalculator.call(make_registration(course, child))
    assert_equal 10_000, result[:price_cents]
    assert_nil result[:discount]
  end

  test "keine Preisreduktion ohne gesetzten Wert pro Training" do
    course = make_course(discounts: false, training_value: nil)
    child  = make_participant(users(:one), first_name: "Anna")
    make_session(course, start_time: 10.days.ago)
    make_session(course, start_time: 3.days.ago)

    result = DiscountCalculator.call(make_registration(course, child))
    assert_equal 10_000, result[:price_cents]
    assert_nil result[:discount]
  end

  test "Preisreduktion nie unter 0" do
    course = make_course(discounts: false, price: 2_000, training_value: 1_000)
    child  = make_participant(users(:one), first_name: "Anna")
    5.times { |i| make_session(course, start_time: (10 - i).days.ago) }

    result = DiscountCalculator.call(make_registration(course, child))
    assert_equal 0, result[:price_cents]
    assert_equal "late_registration", result[:discount]
  end

  test "günstigerer Geschwister-Rabatt gewinnt gegen Preisreduktion für spätes Anmelden" do
    course  = make_course(training_value: 1_000, sibling: 6_000)
    child   = make_participant(users(:one), first_name: "Anna")
    sibling = make_participant(users(:one), first_name: "Ben")
    make_registration(course, sibling, status: "bestätigt")
    make_session(course, start_time: 10.days.ago)
    make_session(course, start_time: 3.days.ago)

    result = DiscountCalculator.call(make_registration(course, child))
    assert_equal 6_000, result[:price_cents]
    assert_equal "sibling", result[:discount]
  end
end
