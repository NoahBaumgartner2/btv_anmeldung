require "test_helper"

class CourseDeactivationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @course = Course.new(title: "Sonntag Tramp", category: "Trampolin", registration_type: "quartal", registration_mode: "quartal",
      location: "RLZ", is_js_training: true, has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    @course.save!(validate: false)
    @session = @course.training_sessions.create!(start_time: 2.weeks.ago, end_time: 2.weeks.ago + 1.hour, attendance_confirmed_at: 2.weeks.ago)
    @registration = CourseRegistration.new(course: @course, participant: participants(:one), status: "bestätigt",
      created_at: 1.month.ago, holiday_deduction_claimed: false)
    @registration.save!(validate: false)
  end

  def deactivate!
    Course.where(id: @course.id).update_all(deactivated_at: Time.current)
    @course.reload
  end

  test "Admin deaktiviert und reaktiviert einen Kurs" do
    sign_in users(:admin)

    post deactivate_course_path(@course)
    assert @course.reload.deactivated?

    get manage_course_path(@course)
    assert_response :success
    assert_match "deaktiviert", response.body

    post reactivate_course_path(@course)
    assert_not @course.reload.deactivated?
  end

  test "offene Anmeldungen verhindern das Deaktivieren" do
    CourseRegistration.new(course: @course, participant: participants(:two), status: "warteliste",
      holiday_deduction_claimed: false).save!(validate: false)
    sign_in users(:admin)

    post deactivate_course_path(@course)

    assert_not @course.reload.deactivated?
  end

  test "normale Benutzer dürfen nicht deaktivieren" do
    sign_in users(:parent_only)

    post deactivate_course_path(@course)

    assert_not @course.reload.deactivated?
  end

  test "Daten eines deaktivierten Kurses sind schreibgeschützt und der Kurs nicht löschbar" do
    attendance = @session.attendances.create!(course_registration: @registration, status: "abwesend")
    deactivate!

    assert_raises(ActiveRecord::ReadOnlyRecord) { @course.destroy! }
    assert_raises(ActiveRecord::ReadOnlyRecord) { CourseRegistration.find(@registration.id).update!(status: "storniert") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { TrainingSession.find(@session.id).update_columns(is_canceled: true) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { Attendance.find(attendance.id).destroy! }
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      @course.course_registrations.new(participant: participants(:two), status: "bestätigt").save!(validate: false)
    end
  end

  test "Trainings-Aktion auf deaktiviertem Kurs endet mit Hinweis statt Fehler" do
    deactivate!
    sign_in users(:admin)

    post cancel_training_session_path(@session), params: { cancellation_reason: "Test" }

    assert_response :see_other
    assert_match "deaktiviert", flash[:alert]
    assert_not @session.reload.is_canceled?
  end

  test "deaktivierter Kurs ist für Familien weg, wird nicht verlängert und nicht gemahnt" do
    @course.update_columns(term_id: terms(:one).id, auto_rollover: true)
    terms(:two).update!(priority_registration_date: 1.day.ago.to_date)
    @session.update_columns(attendance_confirmed_at: nil)
    deactivate!

    assert_not_includes Course.not_ended, @course
    assert @course.ended?
    assert_not @course.rollover_due?

    TrainingSession.where.not(id: @session.id).update_all(attendance_confirmed_at: Time.current)
    AttendanceReminderJob.perform_now
    assert_nil @session.reload.trainer_reminded_at

    sign_in users(:parent_only)
    get course_path(@course)
    assert_redirected_to courses_path
  end

  test "Eltern sehen den deaktivierten Kurs unter Vergangene mit Hinweis, nicht als aktive Karte" do
    registration = CourseRegistration.new(course: @course, participant: participants(:parent_only_child), status: "bestätigt",
      holiday_deduction_claimed: false)
    registration.save!(validate: false)
    @course.training_sessions.create!(start_time: 1.week.from_now, end_time: 1.week.from_now + 1.hour)
    @course.update_columns(end_date: 1.month.from_now)
    deactivate!
    sign_in users(:parent_only)

    get participants_path

    assert_response :success
    assert_select "details p", text: "Sonntag Tramp"
    assert_select "details span", text: "Kurs deaktiviert"
    assert_select "div.border-green-200 h4", text: "Sonntag Tramp", count: 0

    get course_registration_path(registration)

    assert_response :success
    assert_match "Dieser Kurs wurde deaktiviert", response.body
    assert_select "a[href=?]", course_path(@course), count: 0
  end

  test "verschobenes Kind bleibt im J+S-Export des deaktivierten Kurses" do
    participants(:one).update_columns(js_person_number: "1234567")
    target = Course.new(title: "Samstag Tramp", category: "Trampolin", registration_type: "quartal", registration_mode: "quartal",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    target.save!(validate: false)

    RegistrationMoveService.call(@registration, target)
    deactivate!

    assert_equal "anwesend", @session.attendances.find_by(course_registration: @registration).status
    csv = ExportProfile.generate_baspo_awk_csv(@course, 1.month.ago.to_date..Date.current)
    assert_includes csv, "1234567"
  end
end
