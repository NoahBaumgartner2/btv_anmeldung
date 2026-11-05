require "test_helper"

# Schritt 4 aus docs/admin-architektur-plan.md: Kacheln „Handlungsbedarf“ auf der
# Kommandozentrale und die Liste „Offene Zahlungen“.
class AdminActionItemsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:admin)
    @course = courses(:one)
    @course.update_columns(has_payment: true, price_cents: 5000)
    @registration = course_registrations(:one) # bestätigt, nicht bezahlt
  end

  test "payment_open: nur unbezahlte bestätigte/nachgerückte Plätze laufender Bezahlkurse" do
    assert_includes CourseRegistration.payment_open, @registration

    @registration.update_columns(status: "platz_frei")
    assert_includes CourseRegistration.payment_open, @registration

    %w[ausstehend schnuppern storniert warteliste].each do |status|
      @registration.update_columns(status: status)
      assert_not_includes CourseRegistration.payment_open, @registration, status
    end

    @registration.update_columns(status: "bestätigt", payment_cleared: true)
    assert_not_includes CourseRegistration.payment_open, @registration, "bezahlt"

    @registration.update_columns(payment_cleared: false)
    @course.update_columns(end_date: 1.day.ago)
    assert_not_includes CourseRegistration.payment_open, @registration, "Kurs beendet"

    @course.update_columns(end_date: 1.year.from_now, has_payment: false)
    assert_not_includes CourseRegistration.payment_open, @registration, "Gratiskurs"
  end

  test "Kachel zeigt offene Zahlungen mit Anzahl und Link zur Liste" do
    get dashboards_admin_path
    assert_select "section[aria-labelledby=action-items-title] a[href='#{open_payments_dashboard_path}']",
                  text: /#{CourseRegistration.payment_open.count}/
  end

  test "Kachel offene Nachforderungen erscheint nur mit offenem Betrag" do
    SupplementaryCharge.update_all(status: "bezahlt")
    get dashboards_admin_path
    assert_select "section[aria-labelledby=action-items-title] a[href='#{admin_supplementary_charges_path}']", 0
  end

  test "ohne Handlungsbedarf erscheint der Erledigt-Hinweis" do
    @course.update_columns(has_payment: false)
    SupplementaryCharge.update_all(status: "bezahlt")
    Newsletter.update_all(status: "sent")
    TrainingSession.update_all(attendance_confirmed_at: Time.current)
    get dashboards_admin_path
    assert_select "section[aria-labelledby=action-items-title] a", 0
    assert_match I18n.t("dashboards.admin.action_items.all_done"), response.body
  end

  test "Liste Offene Zahlungen zeigt Teilnehmende mit Link zur Kursverwaltung" do
    get open_payments_dashboard_path
    assert_response :success
    assert_select "a[href='#{manage_course_path(@course)}']", text: /#{@registration.participant.last_name}/
  end
end
