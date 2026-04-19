require "test_helper"

class CourseRegistrationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @parent = users(:one)
    @other_parent = users(:two)
    @registration = course_registrations(:one)
    @future_session = training_sessions(:future)
    @past_session = training_sessions(:one)
  end

  # ── unsubscribe_from_session ─────────────────────────────────────────────

  test "creates abgemeldet attendance for own registration" do
    sign_in @parent

    assert_difference "Attendance.count", 1 do
      post unsubscribe_from_session_course_registration_path(@registration),
           params: { training_session_id: @future_session.id }
    end

    assert_redirected_to participants_path
    assert_equal "abgemeldet", Attendance.last.status
    assert_match @registration.participant.first_name, flash[:notice]
  end

  test "updates existing attendance to abgemeldet" do
    sign_in @parent
    # Pre-existing attendance (e.g. trainer toggled anwesend)
    existing = @future_session.attendances.create!(
      course_registration: @registration,
      status: "anwesend"
    )

    assert_no_difference "Attendance.count" do
      post unsubscribe_from_session_course_registration_path(@registration),
           params: { training_session_id: @future_session.id }
    end

    assert_equal "abgemeldet", existing.reload.status
    assert_redirected_to participants_path
  end

  test "cannot unsubscribe from another user's registration" do
    sign_in @other_parent

    post unsubscribe_from_session_course_registration_path(@registration),
         params: { training_session_id: @future_session.id }

    assert_redirected_to root_path
    assert_match "Zugriff verweigert", flash[:alert]
  end

  test "cannot unsubscribe from session within 24 hours" do
    sign_in @parent

    post unsubscribe_from_session_course_registration_path(@registration),
         params: { training_session_id: @past_session.id }

    assert_redirected_to participants_path
    assert_match "24 Stunden", flash[:alert]
    assert_equal 0, @past_session.attendances.where(status: "abgemeldet").count
  end

  test "redirects to login when not authenticated" do
    post unsubscribe_from_session_course_registration_path(@registration),
         params: { training_session_id: @future_session.id }

    assert_redirected_to new_user_session_path
  end

  # ── scan ────────────────────────────────────────────────────────────────────

  test "scan redirects with alert when session_id not found" do
    sign_in @parent  # users(:one) ist auch Trainer (trainer fixture :one)

    post scan_course_registration_path(@registration), params: { session_id: 0 }

    assert_redirected_to root_path
    assert_match "nicht gefunden", flash[:alert]
  end

  test "scan returns 404 JSON when session_id not found" do
    sign_in @parent  # users(:one) ist auch Trainer (trainer fixture :one)

    post scan_course_registration_path(@registration),
         params: { session_id: 0 },
         headers: { "Accept" => "application/json" }

    assert_response :not_found
    body = JSON.parse(response.body)
    assert_equal false, body["success"]
    assert_includes body["message"], "nicht gefunden"
  end
end
