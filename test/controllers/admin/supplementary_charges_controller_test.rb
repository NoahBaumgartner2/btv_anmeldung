require "test_helper"

class Admin::SupplementaryChargesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @course = Course.new(title: "Q4-Korrekturkurs", registration_type: "semester",
      has_payment: true, has_ticketing: false, allows_holiday_deduction: false)
    @course.price_cents = 15_000
    @course.save!(validate: false)

    sign_in users(:admin)
  end

  test "new ist für Nicht-Admins gesperrt" do
    sign_in users(:one)
    get new_admin_supplementary_charge_path
    assert_redirected_to root_path
  end

  test "new zeigt Suchtreffer bei gesetztem q" do
    get new_admin_supplementary_charge_path(q: participants(:one).first_name)
    assert_response :success
    assert_includes @response.body, participants(:one).first_name
  end

  test "new zeigt vorausgewählten Teilnehmer via participant_id-Param" do
    get new_admin_supplementary_charge_path(participant_id: participants(:one).id)
    assert_response :success
    assert_includes @response.body, participants(:one).first_name
    assert_includes @response.body, "checked"
  end

  test "create erstellt für jede ausgewählte Person eine Nachforderung und verschickt Mails" do
    assert_difference("SupplementaryCharge.count", 2) do
      assert_enqueued_emails 2 do
        post admin_supplementary_charges_path, params: {
          participant_ids: [ participants(:one).id, participants(:two).id ],
          course_id:       @course.id,
          amount:          "30.00",
          description:     "Korrektur Rabatt Q4 2026",
          explanation:     "Es wurde fälschlich ein Rabatt angewendet."
        }
      end
    end

    assert_redirected_to admin_supplementary_charges_path
    charge = SupplementaryCharge.order(:created_at).last
    assert_equal 3_000, charge.amount_cents
    assert_equal @course, charge.course
    assert_equal "Korrektur Rabatt Q4 2026", charge.description
    assert_equal "offen", charge.status
    assert_equal users(:admin), charge.created_by
  end

  test "create ohne ausgewählte Personen zeigt Fehler und erstellt nichts" do
    assert_no_difference("SupplementaryCharge.count") do
      post admin_supplementary_charges_path, params: {
        participant_ids: [],
        course_id:       @course.id,
        amount:          "30.00",
        description:     "Test"
      }
    end
    assert_response :unprocessable_entity
  end

  test "create mit ungültigen participant_ids zeigt Fehler statt zu crashen" do
    assert_no_difference("SupplementaryCharge.count") do
      post admin_supplementary_charges_path, params: {
        participant_ids: [ 0 ],
        course_id:       @course.id,
        amount:          "30.00",
        description:     "Test"
      }
    end
    assert_response :unprocessable_entity
  end

  test "create ohne gültigen Betrag zeigt Fehler und erstellt nichts" do
    assert_no_difference("SupplementaryCharge.count") do
      post admin_supplementary_charges_path, params: {
        participant_ids: [ participants(:one).id ],
        course_id:       @course.id,
        amount:          "0",
        description:     "Test"
      }
    end
    assert_response :unprocessable_entity
  end

  test "index zeigt erstellte Nachforderungen" do
    charge = SupplementaryCharge.create!(participant: participants(:one), course: @course,
      amount_cents: 3_000, description: "Sichtbarkeitstest")

    get admin_supplementary_charges_path
    assert_response :success
    assert_includes @response.body, "Sichtbarkeitstest"
  end
end
