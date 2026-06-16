require "test_helper"

class CourseRegistrationsAboTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @parent = users(:one)

    @abo_course = Course.new(
      title: "Abo-Kurs",
      registration_mode: "abo",
      category: "Turnen",
      abo_size: 5,
      start_date: Date.today,
      end_date: 1.year.from_now.to_date,
      registration_type: "kurs"
    )
    @abo_course.save!(validate: false)

    @target_course = Course.new(
      title: "Ziel-Kurs",
      registration_mode: "single_session",
      category: "Turnen",
      start_date: Date.today,
      end_date: 1.year.from_now.to_date,
      registration_type: "kurs"
    )
    @target_course.save!(validate: false)

    @other_category_course = Course.new(
      title: "Anderer-Kurs",
      registration_mode: "single_session",
      category: "Schwimmen",
      start_date: Date.today,
      end_date: 1.year.from_now.to_date,
      registration_type: "kurs"
    )
    @other_category_course.save!(validate: false)

    @participant = participants(:one)

    @abo_reg = CourseRegistration.new(
      course: @abo_course,
      participant: @participant,
      status: "bestätigt",
      abo_entries_total: 5,
      abo_entries_used: 2,
      payment_cleared: true
    )
    @abo_reg.save!(validate: false)

    @future_session = @target_course.training_sessions.create!(
      start_time: 2.days.from_now,
      end_time: 2.days.from_now + 1.hour,
      is_canceled: false
    )

    @other_cat_session = @other_category_course.training_sessions.create!(
      start_time: 3.days.from_now,
      end_time: 3.days.from_now + 1.hour,
      is_canceled: false
    )
  end

  # ── abo_booking? ──────────────────────────────────────────────────────────

  test "abo_booking? gibt true zurück wenn abo_source_registration_id gesetzt" do
    booking = CourseRegistration.new(
      course: @target_course,
      participant: @participant,
      training_session: @future_session,
      abo_source_registration_id: @abo_reg.id,
      status: "bestätigt"
    )
    assert booking.abo_booking?
  end

  test "abo_booking? gibt false zurück wenn kein abo_source_registration_id" do
    assert_not @abo_reg.abo_booking?
  end

  # ── book_abo_session ──────────────────────────────────────────────────────

  test "book_abo_session erstellt CourseRegistration und erhöht abo_entries_used" do
    sign_in @parent

    assert_difference "CourseRegistration.count", 1 do
      post book_abo_session_course_registration_path(@abo_reg),
           params: { training_session_id: @future_session.id }
    end

    assert_redirected_to participants_path
    @abo_reg.reload
    assert_equal 3, @abo_reg.abo_entries_used

    booking = CourseRegistration.last
    assert_equal @abo_reg.id, booking.abo_source_registration_id
    assert_equal "bestätigt", booking.status
    assert booking.payment_cleared?
    assert_equal @future_session.id, booking.training_session_id
  end

  test "book_abo_session lehnt ab wenn Abo erschöpft" do
    @abo_reg.update_columns(abo_entries_used: 5)
    sign_in @parent

    assert_no_difference "CourseRegistration.count" do
      post book_abo_session_course_registration_path(@abo_reg),
           params: { training_session_id: @future_session.id }
    end

    assert_redirected_to abo_sessions_course_registration_path(@abo_reg)
    assert_match I18n.t("course_registrations.flash.abo_exhausted"), flash[:alert]
  end

  test "book_abo_session lehnt ab wenn Training aus falscher Kategorie" do
    sign_in @parent

    assert_no_difference "CourseRegistration.count" do
      post book_abo_session_course_registration_path(@abo_reg),
           params: { training_session_id: @other_cat_session.id }
    end

    assert_redirected_to abo_sessions_course_registration_path(@abo_reg)
    assert_match I18n.t("course_registrations.flash.abo_wrong_category"), flash[:alert]
  end

  test "book_abo_session lehnt Duplikat-Buchung desselben Trainings ab" do
    sign_in @parent

    existing = CourseRegistration.new(
      course: @target_course,
      participant: @participant,
      training_session: @future_session,
      abo_source_registration_id: @abo_reg.id,
      status: "bestätigt",
      payment_cleared: true
    )
    existing.save!(validate: false)

    assert_no_difference "CourseRegistration.count" do
      post book_abo_session_course_registration_path(@abo_reg),
           params: { training_session_id: @future_session.id }
    end

    assert_redirected_to abo_sessions_course_registration_path(@abo_reg)
    assert_match I18n.t("course_registrations.flash.abo_already_booked"), flash[:alert]
  end

  # ── cancel mit Abo-Rückerstattung ─────────────────────────────────────────

  test "cancel einer Abo-Buchung erstattet den Eintritt zurück" do
    sign_in @parent

    booking = CourseRegistration.new(
      course: @target_course,
      participant: @participant,
      training_session: @future_session,
      abo_source_registration_id: @abo_reg.id,
      status: "bestätigt",
      payment_cleared: true
    )
    booking.save!(validate: false)
    @abo_reg.update_columns(abo_entries_used: 3)

    post cancel_course_registration_path(booking)

    assert_redirected_to participants_path
    booking.reload
    assert_equal "storniert", booking.status
    @abo_reg.reload
    assert_equal 2, @abo_reg.abo_entries_used
  end

  test "cancel einer Abo-Buchung erstattet NICHT wenn Session bereits begonnen" do
    sign_in @parent

    past_session = @target_course.training_sessions.create!(
      start_time: 2.hours.ago,
      end_time: 1.hour.ago,
      is_canceled: false
    )

    booking = CourseRegistration.new(
      course: @target_course,
      participant: @participant,
      training_session: past_session,
      abo_source_registration_id: @abo_reg.id,
      status: "bestätigt",
      payment_cleared: true
    )
    booking.save!(validate: false)
    @abo_reg.update_columns(abo_entries_used: 3)

    post cancel_course_registration_path(booking)

    assert_redirected_to participants_path
    @abo_reg.reload
    assert_equal 3, @abo_reg.abo_entries_used
  end

  # ── Duplikat-Validierung übersprungen für Abo-Buchungen ───────────────────

  test "abo_booking überspringt no_duplicate_semester_registration Validierung" do
    booking = CourseRegistration.new(
      course: @abo_course,
      participant: @participant,
      abo_source_registration_id: @abo_reg.id,
      status: "bestätigt",
      payment_cleared: true
    )
    # Wenn das Save gilt OHNE validate: false würde no_duplicate_semester_registration
    # normalerweise fehlschlagen, da @participant bereits @abo_reg auf @abo_course hat.
    # Mit abo_booking? == true darf es NICHT fehlschlagen.
    assert booking.abo_booking?
    booking.validate
    assert_not booking.errors[:base].any? { |e| e.include?("bereits") }
  end
end
