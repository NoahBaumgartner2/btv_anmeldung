require_relative "application_system_test_case"

class CancelOverlaysTest < ApplicationSystemTestCase
  setup do
    @course = Course.new(title: "Zwei Trainer Kurs", registration_type: "quartal", registration_mode: "quartal", has_payment: true,
      price_cents: 15_000, training_value_cents: 2500, has_ticketing: false, allows_holiday_deduction: false)
    @course.save!(validate: false)
    CourseTrainer.without_assignment_notifications { @course.trainers << Trainer.limit(2).to_a }
    [ 3, 2, 1 ].each { |w| @course.training_sessions.create!(start_time: w.weeks.ago, end_time: w.weeks.ago + 1.hour) }
    @session = @course.training_sessions.create!(start_time: 1.week.from_now, end_time: 1.week.from_now + 1.hour)
    @reg = CourseRegistration.new(course: @course, participant: participants(:one), status: "bestätigt", payment_cleared: true,
      sumup_transaction_id: "tx-ok", created_at: 1.month.ago, holiday_deduction_claimed: false)
    @reg.save!(validate: false)
    login_as users(:admin), scope: :user
  end

  test "Abmelden: Overlay lädt die Berechnung, geänderter Betrag ohne Notiz wird abgelehnt" do
    visit manage_course_path(@course)
    page.execute_script("document.querySelector('#dialog-unsubscribe-#{@reg.id}').classList.replace('hidden', 'flex')")

    within "#dialog-unsubscribe-#{@reg.id}" do
      assert_text "Rückerstattung prüfen"
      assert_equal "100.00", find("input[name=refund_amount]").value
      fill_in "refund_amount", with: "90"
      check "refund_confirmed"
      find("button[type=submit]", match: :first).click
    end

    assert_text "Bitte eine Notiz angeben"
    assert_equal "bestätigt", @reg.reload.status
  end

  test "Absagen: Auswahl einzelner Teilnehmender erscheint im Overlay" do
    visit training_session_path(@session)
    click_on I18n.t("training_sessions.show.manage_button")

    assert_no_field "course_registration_ids[]"
    choose I18n.t("training_sessions.show.cancel_scope_selected")
    assert_field "course_registration_ids[]"
    assert_text I18n.t("training_sessions.show.cancel_scope_hint")
  end
end
