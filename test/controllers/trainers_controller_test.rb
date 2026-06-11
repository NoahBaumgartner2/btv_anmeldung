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

  test "trainer with incomplete profile is redirected to my_profile" do
    sign_in users(:one) # trainer :one has only a phone number → incomplete
    get dashboards_trainer_url
    assert_redirected_to my_profile_path
  end

  test "trainer with complete profile is not redirected" do
    trainers(:two).update_columns(
      first_name: "Test", last_name: "Trainer", date_of_birth: "1990-01-01",
      gender: "männlich", ahv_number: "756.1234.5678.90", street: "Musterstrasse",
      house_number: "1", zip_code: "3000", city: "Bern",
      country: "CH", nationality: "CH", mother_tongue: "DE"
    )
    sign_in users(:two)
    get dashboards_trainer_url
    assert_response :success
  end

  test "update_profile with missing required fields renders unprocessable_entity" do
    sign_in users(:one)
    patch update_profile_trainer_url(trainers(:one)), params: {
      trainer: { first_name: "Nur Vorname", last_name: "", phone: "+41791234567" }
    }
    assert_response :unprocessable_entity
    assert_not trainers(:one).reload.profile_complete?
  end
end
