require "test_helper"

class CourseRolloverMailerTest < ActionMailer::TestCase
  test "ready_for_manual_rollover sendet an alle Admins" do
    course = Course.new(
      title: "Rollover-Mail-Testkurs", category: "Turnen",
      registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      term: terms(:one)
    )
    course.save!(validate: false)

    mail = CourseRolloverMailer.ready_for_manual_rollover(course)

    assert_equal User.where(admin: true).pluck(:email), mail.to
    assert_match course.title, mail.subject
    assert_match course.title, mail.body.encoded
  end
end
