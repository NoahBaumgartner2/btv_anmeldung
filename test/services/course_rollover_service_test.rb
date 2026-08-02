require "test_helper"

class CourseRolloverServiceTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  ROLLOVER_DUE_DATE = Date.new(2026, 12, 22) # 3 Wochen vor terms(:two).start_date (2027-01-11)

  def make_course(attrs = {})
    Course.new({
      title: "Rollover Test Kurs", category: "Turnen",
      registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      term: terms(:one), renewal_priority_weeks: 3, public_registration_weeks: 1
    }.merge(attrs)).tap { |c| c.save!(validate: false) }
  end

  test "roll_over! erstellt Nachfolge-Kurs mit den Daten des nächsten Terms" do
    course = make_course
    new_course = travel_to(ROLLOVER_DUE_DATE) { CourseRolloverService.roll_over!(course) }

    assert new_course.persisted?
    assert_equal terms(:two), new_course.term
    assert_equal terms(:two).start_date, new_course.start_date.to_date
    assert_equal terms(:two).end_date, new_course.end_date.to_date
    assert_equal course, new_course.previous_course
    assert_equal course.title, new_course.title
  end

  test "roll_over! kopiert Trainer-Zuweisungen" do
    course = make_course
    trainer = trainers(:one)
    course.course_trainers.create!(trainer: trainer, can_manually_enroll: true)

    new_course = travel_to(ROLLOVER_DUE_DATE) { CourseRolloverService.roll_over!(course) }

    assert_equal 1, new_course.course_trainers.count
    assert_equal trainer, new_course.course_trainers.first.trainer
    assert new_course.course_trainers.first.can_manually_enroll?
  end

  test "roll_over! generiert Trainings am selben Wochentag/Zeit wie der alte Kurs" do
    course = make_course
    old_session = course.training_sessions.create!(
      start_time: Time.zone.local(2026, 8, 19, 17, 0), # Mittwoch 17:00
      end_time: Time.zone.local(2026, 8, 19, 18, 0)
    )

    new_course = travel_to(ROLLOVER_DUE_DATE) { CourseRolloverService.roll_over!(course) }

    assert new_course.training_sessions.any?
    new_course.training_sessions.each do |s|
      assert_equal old_session.start_time.wday, s.start_time.wday
      assert_equal 17, s.start_time.hour
      assert_equal 18, s.end_time.hour
    end
  end

  test "roll_over! überspringt Ferientage bei der Trainings-Generierung" do
    course = make_course
    course.training_sessions.create!(
      start_time: Time.zone.local(2026, 8, 19, 17, 0),
      end_time: Time.zone.local(2026, 8, 19, 18, 0)
    )
    holiday = Holiday.create!(title: "Testferien", start_date: terms(:two).start_date, end_date: terms(:two).start_date + 13.days)

    new_course = travel_to(ROLLOVER_DUE_DATE) { CourseRolloverService.roll_over!(course) }

    new_course.training_sessions.each do |s|
      assert s.start_time.to_date < holiday.start_date || s.start_time.to_date > holiday.end_date,
        "Training #{s.start_time} liegt in den Ferien"
    end
  end

  test "roll_over! benachrichtigt bisherige Teilnehmende per Mail" do
    course = make_course
    reg = CourseRegistration.new(course: course, participant: participants(:one), status: "bestätigt")
    reg.save!(validate: false)
    cancelled = CourseRegistration.new(course: course, participant: participants(:two), status: "storniert")
    cancelled.save!(validate: false)

    assert_enqueued_emails 1 do
      travel_to(ROLLOVER_DUE_DATE) { CourseRolloverService.roll_over!(course) }
    end
  end

  test "roll_over! macht nichts, wenn Kurs noch nicht rollover_due? ist" do
    course = make_course(renewal_priority_weeks: 0)

    travel_to(ROLLOVER_DUE_DATE) do
      assert_not course.rollover_due?

      assert_no_difference("Course.count") do
        result = CourseRolloverService.roll_over!(course)
        assert_nil result
      end
    end
  end
end
