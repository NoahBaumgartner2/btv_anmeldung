require "test_helper"

class RolloverCoursePeriodsJobTest < ActiveJob::TestCase
  ROLLOVER_DUE_DATE = Date.new(2026, 12, 22) # 3 Wochen vor terms(:two).start_date (2027-01-11)

  def make_course(attrs = {})
    Course.new({
      title: "Job Test Kurs", category: "Turnen",
      registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    }.merge(attrs)).tap { |c| c.save!(validate: false) }
  end

  test "verlängert fällige Kurse mit Term" do
    course = make_course(term: terms(:one), renewal_priority_weeks: 3)

    travel_to(ROLLOVER_DUE_DATE) do
      assert_difference("Course.count", 1) do
        RolloverCoursePeriodsJob.perform_now
      end
    end

    assert_equal terms(:two), course.reload.next_course.term
  end

  test "lässt Kurse ohne Term unangetastet" do
    make_course(term: nil)

    travel_to(ROLLOVER_DUE_DATE) do
      assert_no_difference("Course.count") do
        RolloverCoursePeriodsJob.perform_now
      end
    end
  end

  test "verlängert einen Kurs nicht doppelt" do
    course = make_course(term: terms(:one), renewal_priority_weeks: 3)

    travel_to(ROLLOVER_DUE_DATE) do
      RolloverCoursePeriodsJob.perform_now
      assert_no_difference("Course.count") do
        RolloverCoursePeriodsJob.perform_now
      end
    end
  end

  test "rührt Kurse vor Erreichen der Vorlauf-Schwelle nicht an" do
    make_course(term: terms(:one), renewal_priority_weeks: 3)

    travel_to(Date.new(2026, 11, 1)) do
      assert_no_difference("Course.count") do
        RolloverCoursePeriodsJob.perform_now
      end
    end
  end
end
