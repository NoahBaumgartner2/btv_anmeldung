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

  test "update eines unvollständigen Platzhalter-Teilnehmers verschickt Bestätigungsmail nach" do
    placeholder = Participant.new(user: @user, first_name: "Mia", last_name: "Muster")
    placeholder.save!(validate: false)
    course = courses(:one)
    reg = CourseRegistration.new(course: course, participant: placeholder, status: "bestätigt", payment_cleared: false)
    reg.save!(validate: false)

    assert_enqueued_emails 1 do
      patch participant_url(placeholder), params: {
        participant: {
          first_name: "Mia", last_name: "Muster", date_of_birth: "2015-01-01",
          gender: "weiblich", phone_number: "+41 79 123 45 67", ahv_number: "756.1234.5678.90"
        }
      }
    end

    assert_redirected_to participants_url
    job = enqueued_jobs.find { |j| j[:args].first == "CourseRegistrationMailer" }
    assert_equal "confirmation", job[:args][1]
  end

  test "update eines unvollständigen Platzhalter-Teilnehmers bei importiertem Abo verschickt abo_imported-Mail" do
    placeholder = Participant.new(user: @user, first_name: "Mia", last_name: "Muster")
    placeholder.save!(validate: false)
    course = Course.new(
      title: "Abo-Kurs", category: "Turnen",
      registration_type: "abo", registration_mode: "abo", abo_size: 10,
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false
    )
    course.save!(validate: false)
    reg = CourseRegistration.new(
      course: course, participant: placeholder, status: "bestätigt",
      abo_entries_total: 6, abo_entries_used: 0, payment_cleared: true
    )
    reg.save!(validate: false)

    assert_enqueued_emails 1 do
      patch participant_url(placeholder), params: {
        participant: {
          first_name: "Mia", last_name: "Muster", date_of_birth: "2015-01-01",
          gender: "weiblich", phone_number: "+41 79 123 45 67", ahv_number: "756.1234.5678.90"
        }
      }
    end

    job = enqueued_jobs.find { |j| j[:args].first == "CourseRegistrationMailer" }
    assert_equal "abo_imported", job[:args][1]
  end

  test "update eines bereits vollständigen Teilnehmers verschickt keine erneute Bestätigungsmail" do
    assert_enqueued_emails 0 do
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
    end
  end
end
