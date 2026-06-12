require "test_helper"

class DiscountCalculatorTest < ActiveSupport::TestCase
  # ── Setup-Helfer ─────────────────────────────────────────────────────────────

  def make_course(title: "Rabatt-Kurs", category: "polysport", price: 10_000,
                  discounts: true, sibling: 6_000, second: 7_000)
    course = Course.new(title: title, registration_type: "semester",
      has_payment: true, has_ticketing: false, allows_holiday_deduction: false,
      category: category)
    course.price_cents = price
    course.discounts_enabled = discounts
    course.sibling_price_cents = sibling
    course.second_course_price_cents = second
    course.save!(validate: false)
    course
  end

  def make_participant(user, first_name:, last_name: "Kind", dob: Date.new(2014, 1, 1), ahv: nil)
    participant = Participant.new(user: user, first_name: first_name, last_name: last_name,
      date_of_birth: dob, gender: "weiblich", phone_number: "+41790000000", ahv_number: ahv)
    participant.save!(validate: false)
    participant
  end

  def make_registration(course, participant, status: "ausstehend", payment_cleared: false)
    reg = CourseRegistration.new(course: course, participant: participant,
      status: status, payment_cleared: payment_cleared, holiday_deduction_claimed: false)
    reg.save!(validate: false)
    reg
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
end
