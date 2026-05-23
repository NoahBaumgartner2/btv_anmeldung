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
end
