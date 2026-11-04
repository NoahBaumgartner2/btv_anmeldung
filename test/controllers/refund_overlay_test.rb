require "test_helper"

# Rückerstattung im Abmelde-Overlay: Berechnung anzeigen, Betrag ändern, Notiz, bestätigen.
class RefundOverlayTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @course = Course.new(title: "Bezahlkurs", registration_type: "quartal", registration_mode: "quartal", has_payment: true,
      price_cents: 15_000, training_value_cents: 2500, has_ticketing: false, allows_holiday_deduction: false)
    @course.save!(validate: false)
    [ 3, 2, 1 ].each { |w| @course.training_sessions.create!(start_time: w.weeks.ago, end_time: w.weeks.ago + 1.hour) }
    @course.training_sessions.create!(start_time: 2.months.ago, end_time: 2.months.ago + 1.hour)
    @course.training_sessions.create!(start_time: 1.week.from_now, end_time: 1.week.from_now + 1.hour)
    @reg = CourseRegistration.new(course: @course, participant: participants(:parent_only_child), status: "bestätigt", payment_cleared: true,
      sumup_transaction_id: "tx-ok", created_at: 1.month.ago, holiday_deduction_claimed: false)
    @reg.save!(validate: false)
    sign_in users(:admin)
  end

  # Merkt sich den an SumUp gesendeten Betrag, ohne echten Aufruf.
  def with_sumup(result_code = "201")
    sent = {}
    response = Net::HTTPCreated.new("1.1", result_code, "Created")
    response.instance_variable_set(:@body, "{}")
    response.instance_variable_set(:@read, true)
    http = Object.new
    %i[use_ssl= open_timeout= read_timeout=].each { |m| http.define_singleton_method(m) { |_| } }
    http.define_singleton_method(:request) { |req| sent[:amount] = JSON.parse(req.body)["amount"]; response }
    original = Net::HTTP.method(:new)
    Net::HTTP.define_singleton_method(:new) { |*| http }
    yield sent
  ensure
    Net::HTTP.define_singleton_method(:new, original)
  end

  def cancel(params = {}) = post(trainer_cancel_course_registration_path(@reg), params: { refund_review: "1", **params })

  test "Overlay zeigt Trainings, Abzug und vorgeschlagenen Betrag" do
    get refund_preview_course_registration_path(@reg)

    assert_response :success
    assert_match "4 Trainings", response.body
    assert_match "Für die Rückerstattung zählen 3", response.body
    assert_match "2 × CHF 25.00", response.body
    assert_select "ul li", 3
    assert_select "input[name=refund_amount][value='100.00'][max='150.00']"
    assert_select "input[name=refund_confirmed][required]"
  end

  test "berechneter Betrag braucht keine Notiz" do
    with_sumup do |sent|
      cancel(refund_amount: "100.00")
      assert_equal 10_000, sent[:amount]
    end

    @reg.reload
    assert_equal "storniert", @reg.status
    assert @reg.refunded_at
    assert_equal 10_000, @reg.refund_amount_cents
    assert_equal 10_000, @reg.refund_calculated_cents
    assert_match "CHF 100.00", flash[:notice]
  end

  test "geänderter Betrag mit Notiz wird erstattet und festgehalten, Admins sehen die Notiz" do
    with_sumup do |sent|
      cancel(refund_amount: "120.50", refund_note: "Kulanz wegen Umzug")
      assert_equal 12_050, sent[:amount]
    end

    @reg.reload
    assert_equal 12_050, @reg.refund_amount_cents
    assert_equal 10_000, @reg.refund_calculated_cents
    assert_equal "Kulanz wegen Umzug", @reg.refund_note

    mail = CourseRegistrationMailer.admin_refund_done_notice(@reg, users(:admin), 12_050)
    assert_includes mail.text_part.body.decoded, "Kulanz wegen Umzug"
    assert_includes mail.text_part.body.decoded, "Berechnet waren CHF 100.00"

    get course_registration_path(@reg)
    assert_match "Kulanz wegen Umzug", response.body

    sign_out users(:admin)
    sign_in users(:parent_only)
    get course_registration_path(@reg)
    assert_no_match "Kulanz wegen Umzug", response.body
  end

  test "ohne Notiz, zu hoch, negativ oder fehlend: keine Abmeldung und kein Geld" do
    [ { refund_amount: "90" }, { refund_amount: "150.01", refund_note: "x" }, { refund_amount: "-1", refund_note: "x" }, { refund_amount: "abc", refund_note: "x" }, {} ].each do |params|
      with_sumup do |sent|
        cancel(params)
        assert_nil sent[:amount], params.inspect
      end
      assert_equal "bestätigt", @reg.reload.status, params.inspect
      assert_nil @reg.refunded_at
    end
  end

  test "Betrag 0 mit Notiz meldet ab, erstattet nichts und hält es fest" do
    with_sumup do |sent|
      cancel(refund_amount: "0", refund_note: "Wunsch der Familie")
      assert_nil sent[:amount]
    end

    @reg.reload
    assert_equal "storniert", @reg.status
    assert_nil @reg.refunded_at
    assert_equal 0, @reg.refund_amount_cents
  end

  test "ohne gespeicherte Zahlung: Hinweis statt Eingabe, Abmelden bleibt möglich" do
    @reg.update_columns(sumup_transaction_id: nil)

    get refund_preview_course_registration_path(@reg)
    assert_match "keine SumUp-Zahlung", response.body
    assert_select "input[name=refund_amount]", count: 0

    cancel
    assert_equal "storniert", @reg.reload.status
  end

  test "Vorschau nur für Admin und Trainer des Kurses" do
    sign_out users(:admin)
    sign_in users(:parent_only)

    get refund_preview_course_registration_path(@reg)
    assert_redirected_to root_path
  end

  test "Trainer sieht und bestätigt den berechneten Betrag, ändern darf ihn nur ein Admin" do
    trainer = Trainer.first
    CourseTrainer.without_assignment_notifications { @course.trainers << trainer }
    sign_out users(:admin)
    sign_in trainer.user

    get refund_preview_course_registration_path(@reg)
    assert_response :success
    assert_select "input[type=hidden][name=refund_amount][value='100.00']"
    assert_select "input[type=number][name=refund_amount]", count: 0
    assert_select "textarea[name=refund_note]", count: 0

    with_sumup do |sent|
      cancel(refund_amount: "150", refund_note: "mehr bitte")
      assert_nil sent[:amount]
    end
    assert_equal "bestätigt", @reg.reload.status
    assert_match "Nur Admins", flash[:alert]

    with_sumup do |sent|
      cancel(refund_amount: "100.00", refund_note: "wird ignoriert")
      assert_equal 10_000, sent[:amount]
    end
    @reg.reload
    assert_equal "storniert", @reg.status
    assert_nil @reg.refund_note
  end

  test "Kursseite lädt das Overlay nur für bezahlte Anmeldungen" do
    get manage_course_path(@course)
    assert_select "turbo-frame[src*='refund_preview'][loading=lazy]", minimum: 1
    assert_select "input[name=refund_review]", minimum: 1
  end
end
