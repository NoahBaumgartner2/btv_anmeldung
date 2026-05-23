require "test_helper"

class TrainersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @trainer = trainers(:one)
    sign_in users(:admin)
  end

  test "should get index" do
    get trainers_url
    assert_response :success
  end

  test "should get new" do
    get new_trainer_url
    assert_response :success
  end

  test "should create trainer" do
    assert_difference("Trainer.count") do
      post trainers_url, params: { trainer: { phone: "+41799999999", user_id: users(:admin).id } }
    end

    assert_redirected_to my_profile_path
  end

  test "should show trainer" do
    get trainer_url(@trainer)
    assert_response :success
  end

  test "should get edit" do
    get edit_trainer_url(@trainer)
    assert_response :success
  end

  test "should update trainer" do
    patch trainer_url(@trainer), params: { trainer: { phone: @trainer.phone, user_id: @trainer.user_id } }
    assert_redirected_to trainers_url
  end

  test "should destroy trainer" do
    assert_difference("Trainer.count", -1) do
      delete trainer_url(@trainer)
    end

    assert_redirected_to trainers_url
  end
end
