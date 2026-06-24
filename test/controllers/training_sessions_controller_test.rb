require "test_helper"

class TrainingSessionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @training_session = training_sessions(:one)
    sign_in users(:admin)
  end

  test "should get index" do
    get training_sessions_url
    assert_response :success
  end

  test "should get new" do
    get new_training_session_url
    assert_response :success
  end

  test "should create training_session" do
    assert_difference("TrainingSession.count") do
      post training_sessions_url, params: {
        training_session: {
          course_id:   @training_session.course_id,
          end_time:    @training_session.end_time,
          is_canceled: @training_session.is_canceled,
          start_time:  @training_session.start_time
        }
      }
    end

    assert_redirected_to manage_course_path(TrainingSession.last.course)
  end

  test "should show training_session" do
    get training_session_url(@training_session)
    assert_response :success
  end

  test "Schnupper-Anmeldung erscheint nur beim gewählten Training in der Präsenzkontrolle" do
    course = Course.new(
      title: "Schnupper-Präsenz", registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false, allows_trial: true
    )
    course.save!(validate: false)
    session_a = course.training_sessions.create!(start_time: 2.days.from_now, end_time: 2.days.from_now + 1.hour, is_canceled: false)
    session_b = course.training_sessions.create!(start_time: 9.days.from_now, end_time: 9.days.from_now + 1.hour, is_canceled: false)

    # Schnupper-Anmeldung für Session A
    trial = CourseRegistration.new(
      course: course, participant: participants(:one),
      status: "schnuppern", trial_session_id: session_a.id, payment_cleared: false
    )
    trial.save!(validate: false)

    # Regulär bestätigt (ohne Session-Bindung) – erscheint in beiden
    confirmed = CourseRegistration.new(
      course: course, participant: participants(:two),
      status: "bestätigt", payment_cleared: false
    )
    confirmed.save!(validate: false)

    get training_session_url(session_a)
    assert_response :success
    assert_match participants(:one).first_name, @response.body, "Schnupperer muss bei gewähltem Training (A) erscheinen"
    assert_match participants(:two).first_name, @response.body

    get training_session_url(session_b)
    assert_response :success
    assert_no_match(/#{Regexp.escape(participants(:one).first_name)}/, @response.body,
      "Schnupperer darf NICHT bei anderem Training (B) erscheinen")
    assert_match participants(:two).first_name, @response.body, "Bestätigter erscheint weiterhin bei jedem Training"
  end

  test "should get edit" do
    get edit_training_session_url(@training_session)
    assert_response :success
  end

  test "should update training_session" do
    patch training_session_url(@training_session), params: {
      training_session: {
        course_id:   @training_session.course_id,
        end_time:    @training_session.end_time,
        is_canceled: @training_session.is_canceled,
        start_time:  @training_session.start_time
      }
    }
    assert_redirected_to training_session_url(@training_session)
  end

  test "should destroy training_session" do
    assert_difference("TrainingSession.count", -1) do
      delete training_session_url(@training_session)
    end

    assert_redirected_to course_path(@training_session.course)
  end

  test "confirm_attendance marks past session as confirmed" do
    @training_session.update!(attendance_confirmed_at: nil)

    post confirm_attendance_training_session_url(@training_session)

    assert_redirected_to training_session_url(@training_session)
    assert @training_session.reload.attendance_confirmed?
    assert_equal users(:admin), @training_session.attendance_confirmed_by
  end

  test "confirm_attendance is rejected for future session" do
    future = training_sessions(:future)

    post confirm_attendance_training_session_url(future)

    assert_redirected_to training_session_url(future)
    assert_not future.reload.attendance_confirmed?
  end

  test "reopen_attendance clears confirmation" do
    @training_session.confirm_attendance!(users(:admin))

    post reopen_attendance_training_session_url(@training_session)

    assert_redirected_to training_session_url(@training_session)
    assert_not @training_session.reload.attendance_confirmed?
  end

  test "scanner leitet zurück, wenn der Kurs kein Ticketing nutzt" do
    @training_session.course.update!(has_ticketing: false)

    get scanner_training_session_url(@training_session)

    assert_redirected_to training_session_url(@training_session)
    assert_equal I18n.t("training_sessions.show.scanner_not_available"), flash[:alert]
  end

  test "scanner ist erreichbar, wenn der Kurs Ticketing nutzt" do
    @training_session.course.update!(has_ticketing: true)

    get scanner_training_session_url(@training_session)

    assert_response :success
  end
end
