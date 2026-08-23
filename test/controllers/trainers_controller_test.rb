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
    sign_in users(:incomplete_trainer) # trainer :incomplete has only a phone number
    get dashboards_trainer_url
    assert_redirected_to my_profile_path
  end

  test "trainer with complete profile is not redirected" do
    sign_in users(:two) # trainer :two is complete via fixture
    get dashboards_trainer_url
    assert_response :success
  end

  test "update_profile with missing required fields renders unprocessable_entity" do
    sign_in users(:incomplete_trainer)
    patch update_profile_trainer_url(trainers(:incomplete)), params: {
      trainer: { first_name: "Nur Vorname", last_name: "", phone: "+41791234567" }
    }
    assert_response :unprocessable_entity
    assert_not trainers(:incomplete).reload.profile_complete?
  end

  test "update_profile mit geänderter Adresse benachrichtigt Admins" do
    sign_out users(:admin)
    trainer = trainers(:two)
    sign_in trainer.user

    assert_enqueued_email_with CourseTrainerMailer, :profile_updated_admin_notice,
      args: [ trainer, [ "Strasse" ], users(:admin) ] do
      patch update_profile_trainer_url(trainer), params: {
        trainer: {
          first_name: trainer.first_name, last_name: trainer.last_name, phone: trainer.phone,
          date_of_birth: trainer.date_of_birth, gender: trainer.gender, ahv_number: trainer.ahv_number,
          street: "Neue Strasse", house_number: trainer.house_number, zip_code: trainer.zip_code,
          city: trainer.city, country: trainer.country, nationality: trainer.nationality,
          mother_tongue: trainer.mother_tongue
        }
      }
    end
  end

  test "update_profile ohne echte Änderung benachrichtigt niemanden" do
    sign_out users(:admin)
    trainer = trainers(:two)
    sign_in trainer.user

    assert_no_enqueued_emails do
      patch update_profile_trainer_url(trainer), params: {
        trainer: {
          first_name: trainer.first_name, last_name: trainer.last_name, phone: trainer.phone,
          date_of_birth: trainer.date_of_birth, gender: trainer.gender, ahv_number: trainer.ahv_number,
          street: trainer.street, house_number: trainer.house_number, zip_code: trainer.zip_code,
          city: trainer.city, country: trainer.country, nationality: trainer.nationality,
          mother_tongue: trainer.mother_tongue
        }
      }
    end
  end

  test "substitutes zeigt Ersatztrainings gruppiert nach Trainer:in" do
    training_sessions(:one).update!(substitute_trainer: trainers(:two))

    get substitutes_trainers_url
    assert_response :success
    assert_match trainers(:two).full_name, @response.body
  end

  test "substitutes filtert nach Monat" do
    training_sessions(:one).update!(substitute_trainer: trainers(:two)) # start_time: 2026-03-29

    get substitutes_trainers_url(month: "2026-03")
    assert_response :success
    assert_match trainers(:two).full_name, @response.body

    get substitutes_trainers_url(month: "2026-04")
    assert_response :success
    assert_no_match(/#{Regexp.escape(trainers(:two).full_name)}/, @response.body)
  end
end
