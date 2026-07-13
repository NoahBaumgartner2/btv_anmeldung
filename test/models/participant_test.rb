require "test_helper"

class ParticipantTest < ActiveSupport::TestCase
  setup do
    @participant = participants(:one)
    @course = Course.new(
      title: "Schnupper-Kurs",
      category: "Kids Gym",
      registration_type: "Kids Gym",
      registration_mode: "Kids Gym",
      has_payment: false,
      has_ticketing: false,
      allows_holiday_deduction: false
    )
    @course.save!(validate: false)
  end

  test "has_trialed_in_category? returns false when no trial registration exists" do
    assert_not @participant.has_trialed_in_category?("Kids Gym")
  end

  test "has_trialed_in_category? returns true when active trial exists within 7 days" do
    reg = CourseRegistration.new(
      course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)

    assert @participant.has_trialed_in_category?("Kids Gym")
  end

  test "has_trialed_in_category? returns false for different registration_type" do
    reg = CourseRegistration.new(
      course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)

    assert_not @participant.has_trialed_in_category?("Krabbel Gym")
  end

  test "has_trialed_in_category? returns false when trial is older than 7 days" do
    reg = CourseRegistration.new(
      course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)
    # Frist beginnt jetzt nach dem Schnuppertraining → abgelaufenes Fenster über trial_expires_at simulieren
    reg.update_column(:trial_expires_at, 1.day.ago)

    assert_not @participant.has_trialed_in_category?("Kids Gym")
  end

  test "ever_trialed_in_category? returns false when no trial exists" do
    assert_not @participant.ever_trialed_in_category?("Kids Gym")
  end

  test "ever_trialed_in_category? returns true for active trial" do
    reg = CourseRegistration.new(
      course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)

    assert @participant.ever_trialed_in_category?("Kids Gym")
  end

  test "ever_trialed_in_category? returns true even for expired trial" do
    reg = CourseRegistration.new(
      course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)
    reg.update_column(:created_at, 30.days.ago)

    assert @participant.ever_trialed_in_category?("Kids Gym")
  end

  test "ever_trialed_in_category? returns false for different category" do
    reg = CourseRegistration.new(
      course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    reg.save!(validate: false)

    assert_not @participant.ever_trialed_in_category?("Krabbel Gym")
  end

  # ── schnupper_eligible_for_category? ──────────────────────────────────────

  test "schnupper_eligible_for_category? returns true when no registrations exist" do
    assert @participant.schnupper_eligible_for_category?("Kids Gym")
  end

  test "schnupper_eligible_for_category? returns false when already trialed" do
    reg = CourseRegistration.new(course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false)
    reg.save!(validate: false)
    assert_not @participant.schnupper_eligible_for_category?("Kids Gym")
  end

  test "schnupper_eligible_for_category? returns false when already confirmed in same category" do
    reg = CourseRegistration.new(course: @course, participant: @participant,
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false)
    reg.save!(validate: false)
    assert_not @participant.schnupper_eligible_for_category?("Kids Gym")
  end

  test "schnupper_eligible_for_category? returns false when previously confirmed but now cancelled" do
    reg = CourseRegistration.new(course: @course, participant: @participant,
      status: "storniert", payment_cleared: false, holiday_deduction_claimed: false)
    reg.save!(validate: false)
    assert_not @participant.schnupper_eligible_for_category?("Kids Gym")
  end

  test "schnupper_eligible_for_category? returns true when a trial was cancelled" do
    reg = CourseRegistration.new(course: @course, participant: @participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false)
    reg.save!(validate: false)
    reg.update!(status: "storniert", cancelled_at: Time.current)

    assert @participant.schnupper_eligible_for_category?("Kids Gym")
  end

  # ── Identitäts-basierte Duplikat-Erkennung ────────────────────────────────

  test "ever_trialed_in_category? returns true when sibling with same AHV has trialed" do
    subject = Participant.new(
      user: users(:one), first_name: "Anna", last_name: "Muster",
      date_of_birth: Date.new(2012, 3, 15), gender: "w",
      phone_number: "0791000001", ahv_number: "756.9999.0001.11"
    ).tap { |p| p.save!(validate: false) }

    sibling = Participant.new(
      user: users(:two), first_name: "Anna", last_name: "Muster",
      date_of_birth: Date.new(2012, 3, 15), gender: "w",
      phone_number: "0791000002", ahv_number: "756.9999.0001.11"
    ).tap { |p| p.save!(validate: false) }

    CourseRegistration.new(course: @course, participant: sibling,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    ).tap { |r| r.save!(validate: false) }

    assert subject.ever_trialed_in_category?("Kids Gym")
  end

  test "ever_trialed_in_category? returns true when sibling with same name and DOB has trialed" do
    subject = Participant.new(
      user: users(:one), first_name: "Ben", last_name: "Beispiel",
      date_of_birth: Date.new(2013, 6, 20), gender: "m",
      phone_number: "0791000003", ahv_number: nil
    ).tap { |p| p.save!(validate: false) }

    sibling = Participant.new(
      user: users(:two), first_name: "Ben", last_name: "Beispiel",
      date_of_birth: Date.new(2013, 6, 20), gender: "m",
      phone_number: "0791000004", ahv_number: nil
    ).tap { |p| p.save!(validate: false) }

    CourseRegistration.new(course: @course, participant: sibling,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    ).tap { |r| r.save!(validate: false) }

    assert subject.ever_trialed_in_category?("Kids Gym")
  end

  test "ever_trialed_in_category? returns false when sibling has same name but different DOB" do
    subject = Participant.new(
      user: users(:one), first_name: "Clara", last_name: "Test",
      date_of_birth: Date.new(2011, 4, 10), gender: "w",
      phone_number: "0791000005", ahv_number: nil
    ).tap { |p| p.save!(validate: false) }

    other = Participant.new(
      user: users(:two), first_name: "Clara", last_name: "Test",
      date_of_birth: Date.new(2012, 4, 10), gender: "w",
      phone_number: "0791000006", ahv_number: nil
    ).tap { |p| p.save!(validate: false) }

    CourseRegistration.new(course: @course, participant: other,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    ).tap { |r| r.save!(validate: false) }

    assert_not subject.ever_trialed_in_category?("Kids Gym")
  end

  # ── ahv_required_for? ────────────────────────────────────────────────────────

  test "ahv_required_for? returns true for participant aged 20 at course start" do
    course = Course.new(start_date: Date.new(2026, 9, 1))
    participant = Participant.new(date_of_birth: Date.new(2006, 1, 1)) # turns 20 before Sep 1
    assert participant.ahv_required_for?(course)
  end

  test "ahv_required_for? returns true for participant aged exactly 20 at course start" do
    course = Course.new(start_date: Date.new(2026, 9, 1))
    participant = Participant.new(date_of_birth: Date.new(2006, 9, 1)) # exactly 20 on start day
    assert participant.ahv_required_for?(course)
  end

  test "ahv_required_for? returns false for participant aged 21 at course start" do
    course = Course.new(start_date: Date.new(2026, 9, 1))
    participant = Participant.new(date_of_birth: Date.new(2004, 12, 31)) # turns 21 before Sep 1
    assert_not participant.ahv_required_for?(course)
  end

  test "ahv_required_for? returns true when date_of_birth is nil" do
    course = Course.new(start_date: Date.new(2026, 9, 1))
    participant = Participant.new(date_of_birth: nil)
    assert participant.ahv_required_for?(course)
  end

  # ── missing_fields_for (AHV-Altersregel) ─────────────────────────────────────

  test "missing_fields_for includes ahv_number for participant aged <=20 without AHV" do
    course = Course.new(start_date: Date.new(2026, 9, 1))
    course.save!(validate: false)
    participant = Participant.new(
      user: users(:one), first_name: "Jung", last_name: "Kind",
      date_of_birth: Date.new(2006, 1, 1), gender: "weiblich",
      phone_number: "0791000099", ahv_number: nil
    )
    assert_includes participant.missing_fields_for(course), :ahv_number
  end

  test "missing_fields_for excludes ahv_number for participant aged >20 without AHV (course has no required fields)" do
    course = Course.new(start_date: Date.new(2026, 9, 1))
    course.save!(validate: false)
    participant = Participant.new(
      user: users(:one), first_name: "Erwachsen", last_name: "Person",
      date_of_birth: Date.new(2004, 12, 31), gender: "weiblich",
      phone_number: "0791000098", ahv_number: nil
    )
    assert_not_includes participant.missing_fields_for(course), :ahv_number
  end

  # ── AHV-Löschschutz ───────────────────────────────────────────────────────

  test "ahv_number cannot be cleared once set" do
    p = participants(:parent_only_child)
    p.ahv_number = ""
    assert_not p.valid?
    assert_includes p.errors[:ahv_number], "kann nicht gelöscht werden"
  end

  test "ahv_number can be changed to another valid value" do
    p = participants(:parent_only_child)
    p.ahv_number = "756.1234.5678.97"
    assert p.valid?, p.errors.full_messages.to_s
  end

  test "ahv_number can remain the same on update" do
    p = participants(:parent_only_child)
    p.first_name = "Updated"
    assert p.valid?, p.errors.full_messages.to_s
  end

  test "ahv_number can be set for the first time on update" do
    p = participants(:one)
    p.ahv_number = "756.1234.5678.97"
    assert p.valid?, p.errors.full_messages.to_s
  end

  test "ever_trialed_in_category? returns false when other participant has different AHV" do
    subject = Participant.new(
      user: users(:one), first_name: "David", last_name: "Demo",
      date_of_birth: Date.new(2010, 1, 1), gender: "m",
      phone_number: "0791000007", ahv_number: "756.8888.0001.11"
    ).tap { |p| p.save!(validate: false) }

    other = Participant.new(
      user: users(:two), first_name: "David", last_name: "Demo",
      date_of_birth: Date.new(2010, 1, 1), gender: "m",
      phone_number: "0791000008", ahv_number: "756.8888.9999.99"
    ).tap { |p| p.save!(validate: false) }

    CourseRegistration.new(course: @course, participant: other,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    ).tap { |r| r.save!(validate: false) }

    assert_not subject.ever_trialed_in_category?("Kids Gym")
  end

  # Telefon-Validierung: gültige Nummern dürfen nicht an Trennzeichen scheitern.
  test "phone_number akzeptiert gängige Schreibweisen mit Trennzeichen" do
    [
      "+41 78 911 29 00",             # normale Leerzeichen
      "+41 78 911 29 00", # geschützte Leerzeichen (NBSP, Copy-Paste)
      "+41 (0)78 911 29 00",          # Klammern
      "+41.78.911.29.00",             # Punkte
      "078 911 29 00"                 # ohne Ländervorwahl
    ].each do |number|
      @participant.phone_number = number
      @participant.valid?
      assert_empty @participant.errors[:phone_number],
        "#{number.inspect} sollte als gültige Telefonnummer akzeptiert werden"
    end
  end

  test "phone_number lehnt Nummern mit weniger als 7 Ziffern ab" do
    [ "123", "12 34 5", "+41 0" ].each do |number|
      @participant.phone_number = number
      @participant.valid?
      assert_includes @participant.errors[:phone_number],
        "muss mindestens 7 Ziffern haben (erlaubt: +, Ziffern, Leerzeichen, -)",
        "#{number.inspect} sollte abgelehnt werden"
    end
  end
end
