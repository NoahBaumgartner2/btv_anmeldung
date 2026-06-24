require "test_helper"

class WaitlistPromotionServiceTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper

  def make_course(attrs = {})
    Course.new({
      title: "Waitlist Test Kurs", registration_type: "semester",
      has_payment: false, has_ticketing: false,
      allows_holiday_deduction: false, max_participants: 2,
      enable_waitlist: true, price_cents: 0
    }.merge(attrs)).tap { |c| c.save!(validate: false) }
  end

  test "promotes waitlisted registration to bestätigt for free course" do
    course = make_course(max_participants: 1, has_payment: false, price_cents: 0)

    confirmed = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false
    )
    confirmed.save!(validate: false)

    waitlisted = CourseRegistration.new(
      course: course, participant: participants(:two),
      status: "warteliste", payment_cleared: false, holiday_deduction_claimed: false
    )
    waitlisted.save!(validate: false)

    confirmed.destroy!

    assert_enqueued_emails 1 do
      WaitlistPromotionService.promote_next_from_waitlist(course.reload)
    end

    assert_equal "bestätigt", waitlisted.reload.status
  end

  test "promotes waitlisted registration to ausstehend for paid course" do
    course = make_course(max_participants: 1, has_payment: true, price_cents: 5000)

    confirmed = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false
    )
    confirmed.save!(validate: false)

    waitlisted = CourseRegistration.new(
      course: course, participant: participants(:two),
      status: "warteliste", payment_cleared: false, holiday_deduction_claimed: false
    )
    waitlisted.save!(validate: false)

    confirmed.destroy!

    assert_enqueued_emails 1 do
      WaitlistPromotionService.promote_next_from_waitlist(course.reload)
    end

    assert_equal "ausstehend", waitlisted.reload.status
  end

  test "ausstehend belegt KEINEN Platz: Wartender wird trotz offenem Checkout hochgestuft" do
    course = make_course(max_participants: 1, has_payment: true, price_cents: 5000)

    # Offener/abgebrochener Checkout eines anderen Teilnehmers – darf den Platz NICHT blockieren.
    pending_reg = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "ausstehend", payment_cleared: false, holiday_deduction_claimed: false
    )
    pending_reg.save!(validate: false)

    waitlisted = CourseRegistration.new(
      course: course, participant: participants(:two),
      status: "warteliste", payment_cleared: false, holiday_deduction_claimed: false
    )
    waitlisted.save!(validate: false)

    assert_enqueued_emails 1 do
      WaitlistPromotionService.promote_next_from_waitlist(course.reload)
    end

    # Bezahlkurs → Hochstufung auf "ausstehend" (Zahlung folgt), nicht mehr "warteliste".
    assert_equal "ausstehend", waitlisted.reload.status
  end

  test "does nothing when no waitlisted registrations exist" do
    course = make_course(max_participants: 5)

    assert_enqueued_emails 0 do
      WaitlistPromotionService.promote_next_from_waitlist(course)
    end
  end

  test "promotes abo waitlist booking to bestätigt even on paid course" do
    course = make_course(max_participants: 1, has_payment: true, price_cents: 5000)

    abo_source_course = Course.new(
      title: "Abo-Quelle", registration_mode: "abo",
      category: "Turnen", abo_size: 5,
      start_date: Date.today, end_date: 1.year.from_now.to_date,
      registration_type: "kurs"
    )
    abo_source_course.save!(validate: false)

    abo_source = CourseRegistration.new(
      course: abo_source_course, participant: participants(:one),
      status: "bestätigt", abo_entries_total: 5, abo_entries_used: 1,
      payment_cleared: true
    )
    abo_source.save!(validate: false)

    confirmed = CourseRegistration.new(
      course: course, participant: participants(:parent_only_child),
      status: "bestätigt", payment_cleared: true
    )
    confirmed.save!(validate: false)

    session = course.training_sessions.create!(
      start_time: 2.days.from_now, end_time: 2.days.from_now + 1.hour, is_canceled: false
    )

    waitlisted = CourseRegistration.new(
      course: course, participant: participants(:one),
      training_session: session,
      abo_source_registration_id: abo_source.id,
      status: "warteliste", payment_cleared: true
    )
    waitlisted.save!(validate: false)

    confirmed.destroy!

    assert_enqueued_emails 1 do
      WaitlistPromotionService.promote_next_from_waitlist(course.reload, training_session_id: session.id)
    end

    assert_equal "bestätigt", waitlisted.reload.status
  end

  test "promotes to platz_frei (Entscheidung offen) when participant may still trial" do
    course = make_course(max_participants: 1, has_payment: false, price_cents: 0,
                         allows_trial: true, category: "Probier-Kategorie")

    confirmed = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false
    )
    confirmed.save!(validate: false)

    waitlisted = CourseRegistration.new(
      course: course, participant: participants(:two),
      status: "warteliste", payment_cleared: false, holiday_deduction_claimed: false
    )
    waitlisted.save!(validate: false)

    confirmed.destroy!

    assert_enqueued_emails 1 do
      WaitlistPromotionService.promote_next_from_waitlist(course.reload)
    end

    waitlisted.reload
    assert_equal "platz_frei", waitlisted.status
    assert waitlisted.payment_expires_at.present?, "7-Tage-Entscheidfrist muss gesetzt sein"
  end

  test "promotes to bestätigt (no choice) when participant already trialed in category" do
    course = make_course(max_participants: 1, has_payment: false, price_cents: 0,
                         allows_trial: true, category: "Schon-Geschnuppert")

    # Teilnehmer hat in dieser Kategorie bereits (in einem anderen Kurs) geschnuppert
    other = Course.new(title: "Anderer Kurs", registration_type: "semester",
                       category: "Schon-Geschnuppert", has_payment: false,
                       has_ticketing: false, allows_holiday_deduction: false)
    other.save!(validate: false)
    CourseRegistration.new(course: other, participant: participants(:two),
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false)
      .save!(validate: false)

    confirmed = CourseRegistration.new(course: course, participant: participants(:one),
      status: "bestätigt", payment_cleared: false, holiday_deduction_claimed: false)
    confirmed.save!(validate: false)

    waitlisted = CourseRegistration.new(course: course, participant: participants(:two),
      status: "warteliste", payment_cleared: false, holiday_deduction_claimed: false)
    waitlisted.save!(validate: false)

    confirmed.destroy!

    WaitlistPromotionService.promote_next_from_waitlist(course.reload)

    assert_equal "bestätigt", waitlisted.reload.status
  end

  test "platz_frei occupies a slot and is not double-assigned" do
    course = make_course(max_participants: 1, has_payment: false, price_cents: 0,
                         allows_trial: true, category: "Belegt-Test")

    offered = CourseRegistration.new(course: course, participant: participants(:one),
      status: "platz_frei", payment_expires_at: 7.days.from_now,
      payment_cleared: false, holiday_deduction_claimed: false)
    offered.save!(validate: false)

    waitlisted = CourseRegistration.new(course: course, participant: participants(:two),
      status: "warteliste", payment_cleared: false, holiday_deduction_claimed: false)
    waitlisted.save!(validate: false)

    assert_enqueued_emails 0 do
      WaitlistPromotionService.promote_next_from_waitlist(course.reload)
    end

    assert_equal "warteliste", waitlisted.reload.status
  end

  test "does nothing when waitlist is not enabled" do
    course = make_course(enable_waitlist: false, max_participants: 1)

    waitlisted = CourseRegistration.new(
      course: course, participant: participants(:parent_only_child),
      status: "warteliste", payment_cleared: false, holiday_deduction_claimed: false
    )
    waitlisted.save!(validate: false)

    WaitlistPromotionService.promote_next_from_waitlist(course)

    assert_equal "warteliste", waitlisted.reload.status
  end
end
