require "test_helper"

class CourseRegistrationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @parent = users(:one)
    @other_parent = users(:two)
    @registration = course_registrations(:one)
    @future_session = training_sessions(:future)
    @past_session = training_sessions(:one)

    @trial_parent = users(:parent_only)
    @trial_participant = participants(:parent_only_child)
    @trial_course = Course.new(
      title: "Schnupper-Kurs",
      registration_type: "semester",
      registration_mode: "semester",
      has_payment: false,
      has_ticketing: false,
      allows_holiday_deduction: false,
      allows_trial: true,
      requires_ahv_number: true
    )
    @trial_course.save!(validate: false)
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

  # ── Schnuppern ────────────────────────────────────────────────────────────

  test "creates schnupper registration when trial param is true and course allows trial" do
    sign_in @trial_parent

    assert_difference "CourseRegistration.count", 1 do
      post course_registrations_path, params: {
        course_registration: {
          course_id: @trial_course.id,
          participant_id: @trial_participant.id
        },
        trial: "true"
      }
    end

    reg = CourseRegistration.last
    assert_equal "schnuppern", reg.status
    assert_redirected_to course_registration_path(reg)
    assert_match "Schnupperplatz", flash[:notice]
  end

  test "rejects trial when course does not allow trial" do
    @trial_course.update_column(:allows_trial, false)
    sign_in @trial_parent

    assert_no_difference "CourseRegistration.count" do
      post course_registrations_path, params: {
        course_registration: {
          course_id: @trial_course.id,
          participant_id: @trial_participant.id
        },
        trial: "true"
      }
    end

    assert_response :unprocessable_entity
  end

  test "rejects trial when participant already trialed in same category" do
    existing = CourseRegistration.new(
      course: @trial_course, participant: @trial_participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    existing.save!(validate: false)

    sign_in @trial_parent

    assert_no_difference "CourseRegistration.count" do
      post course_registrations_path, params: {
        course_registration: {
          course_id: @trial_course.id,
          participant_id: @trial_participant.id
        },
        trial: "true"
      }
    end

    assert_response :unprocessable_entity
  end

  test "does not redirect to payment when trial even if course has payment" do
    @trial_course.update_columns(has_payment: true, price_cents: 10_000)
    sign_in @trial_parent

    assert_difference "CourseRegistration.count", 1 do
      post course_registrations_path, params: {
        course_registration: {
          course_id: @trial_course.id,
          participant_id: @trial_participant.id
        },
        trial: "true"
      }
    end

    reg = CourseRegistration.last
    assert_equal "schnuppern", reg.status
    assert_redirected_to course_registration_path(reg)
  end

  # ── trial_eligible ────────────────────────────────────────────────────────

  test "trial_eligible returns eligible: true when participant has never trialed in category" do
    sign_in @trial_parent

    get trial_eligible_course_registrations_path, params: {
      course_id: @trial_course.id,
      participant_id: @trial_participant.id
    }, as: :json

    assert_response :ok
    assert_equal true, response.parsed_body["eligible"]
  end

  test "trial_eligible returns eligible: false when participant already trialed in same category" do
    existing = CourseRegistration.new(
      course: @trial_course, participant: @trial_participant,
      status: "schnuppern", payment_cleared: false, holiday_deduction_claimed: false
    )
    existing.save!(validate: false)

    sign_in @trial_parent

    get trial_eligible_course_registrations_path, params: {
      course_id: @trial_course.id,
      participant_id: @trial_participant.id
    }, as: :json

    assert_response :ok
    assert_equal false, response.parsed_body["eligible"]
  end

  test "trial_eligible returns eligible: false when course does not allow trial" do
    @trial_course.update_column(:allows_trial, false)
    sign_in @trial_parent

    get trial_eligible_course_registrations_path, params: {
      course_id: @trial_course.id,
      participant_id: @trial_participant.id
    }, as: :json

    assert_response :ok
    assert_equal false, response.parsed_body["eligible"]
  end

  test "trial_eligible returns eligible: false for unknown participant" do
    sign_in @trial_parent

    get trial_eligible_course_registrations_path, params: {
      course_id: @trial_course.id,
      participant_id: 0
    }, as: :json

    assert_response :ok
    assert_equal false, response.parsed_body["eligible"]
  end
end
