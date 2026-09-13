require "test_helper"

class Admin::AgeExemptionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @alt = make_course(title: "Kutu Alt", term: terms(:one), start_date: Date.new(2026, 8, 17))
    @neu = make_course(title: "Kutu Neu", term: terms(:two), start_date: Date.new(2027, 1, 11),
      previous_course: @alt)

    # Am 11.1.2027 zwölf -> zu alt für den Nachfolgekurs (max_age 10).
    @zu_alt = Participant.new(user: users(:one), first_name: "Ueberalt", last_name: "Kind",
      date_of_birth: Date.new(2014, 1, 1), gender: "weiblich", phone_number: "+41790000000")
    @zu_alt.save!(validate: false)
    CourseRegistration.new(course: @alt, participant: @zu_alt, status: "bestätigt").save!(validate: false)

    sign_in users(:admin)
  end

  def make_course(title:, term:, start_date:, previous_course: nil)
    course = Course.new(title: title, registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      term: term, max_age: 10, previous_course: previous_course)
    course.start_date = start_date
    course.end_date = start_date + 4.months
    course.save!(validate: false)
    course
  end

  test "index ist für Nicht-Admins gesperrt" do
    sign_in users(:one)
    get admin_age_exemptions_path
    assert_redirected_to root_path
  end

  test "index zeigt die zu alten Personen des gewählten Zeitraums" do
    get admin_age_exemptions_path(term_id: terms(:two).id)
    assert_response :success
    assert_includes @response.body, "Ueberalt"
    assert_includes @response.body, @neu.title
  end

  test "index ohne term_id fällt auf einen Zeitraum zurück statt zu crashen" do
    get admin_age_exemptions_path
    assert_response :success
  end

  test "create erteilt eine Altersausnahme" do
    assert_difference("AgeExemption.count", 1) do
      post admin_age_exemptions_path, params: {
        participant_id: @zu_alt.id, course_id: @neu.id, term_id: terms(:two).id,
        note: "Darf das Semester fertig machen"
      }
    end

    assert_redirected_to admin_age_exemptions_path(term_id: terms(:two).id.to_s)
    exemption = AgeExemption.last
    assert_equal @zu_alt, exemption.participant
    assert_equal @neu, exemption.course
    assert_equal users(:admin), exemption.granted_by
    assert_equal "Darf das Semester fertig machen", exemption.note
  end

  test "create verschickt keine E-Mail" do
    assert_no_enqueued_emails do
      post admin_age_exemptions_path, params: {
        participant_id: @zu_alt.id, course_id: @neu.id, term_id: terms(:two).id
      }
    end
  end

  test "create ist idempotent und legt keine Duplikate an" do
    2.times do
      post admin_age_exemptions_path, params: {
        participant_id: @zu_alt.id, course_id: @neu.id, term_id: terms(:two).id
      }
    end

    assert_equal 1, AgeExemption.where(participant: @zu_alt, course: @neu).count
  end

  test "create mit unbekannter Person meldet einen Fehler" do
    assert_no_difference("AgeExemption.count") do
      post admin_age_exemptions_path, params: {
        participant_id: 0, course_id: @neu.id, term_id: terms(:two).id
      }
    end
    assert_equal "Person oder Kurs nicht gefunden.", flash[:alert]
  end

  test "destroy entfernt die Altersausnahme wieder" do
    exemption = AgeExemption.create!(participant: @zu_alt, course: @neu)

    assert_difference("AgeExemption.count", -1) do
      delete admin_age_exemption_path(exemption, term_id: terms(:two).id)
    end
    assert_redirected_to admin_age_exemptions_path(term_id: terms(:two).id.to_s)
  end

  test "erteilte Ausnahme hebt die Altersblockade bei der Anmeldung auf" do
    assert @neu.registration_blocked_by_age?(@zu_alt), "vor der Ausnahme blockiert"

    post admin_age_exemptions_path, params: {
      participant_id: @zu_alt.id, course_id: @neu.id, term_id: terms(:two).id
    }

    assert_not @neu.reload.registration_blocked_by_age?(@zu_alt), "nach der Ausnahme erlaubt"
  end
end
