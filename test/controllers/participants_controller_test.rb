require "test_helper"

class ParticipantsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    # parent_only is a plain parent (no trainer record, no admin) — owns parent_only_child
    @user        = users(:parent_only)
    @participant = participants(:parent_only_child)
    sign_in @user
  end

  test "should get index" do
    get participants_url
    assert_response :success
  end

  test "should get new" do
    get new_participant_url
    assert_response :success
  end

  test "should create participant" do
    assert_difference("Participant.count") do
      post participants_url, params: {
        participant: {
          ahv_number:   "756.9999.8888.77",
          date_of_birth: @participant.date_of_birth,
          first_name:   "Test",
          gender:       @participant.gender,
          last_name:    "Kind",
          phone_number: @participant.phone_number
        }
      }
    end

    assert_redirected_to participants_url
  end

  test "should show participant" do
    get participant_url(@participant)
    assert_response :success
  end

  test "should get edit" do
    get edit_participant_url(@participant)
    assert_response :success
  end

  test "should update participant" do
    patch participant_url(@participant), params: {
      participant: {
        ahv_number:    @participant.ahv_number,
        date_of_birth: @participant.date_of_birth,
        first_name:    @participant.first_name,
        gender:        @participant.gender,
        last_name:     @participant.last_name,
        phone_number:  @participant.phone_number
      }
    }
    assert_redirected_to participants_url
  end

  test "should destroy participant" do
    assert_difference("Participant.count", -1) do
      delete participant_url(@participant)
    end

    assert_redirected_to participants_url
  end
end
