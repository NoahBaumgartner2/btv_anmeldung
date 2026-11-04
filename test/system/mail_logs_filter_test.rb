require_relative "application_system_test_case"

class MailLogsFilterTest < ApplicationSystemTestCase
  test "Zeitraum im Kalender wählen und filtern" do
    MailLog.create!(kind: "course_registration.confirmation", course_title: "Heute", participant_name: "Sichtbar Kind", audience: "parent")
    MailLog.create!(kind: "course_registration.confirmation", course_title: "Alt", participant_name: "Altes Kind", audience: "parent", created_at: 3.years.ago)
    login_as users(:admin), scope: :user
    visit mail_logs_path

    click_button I18n.t("mail_logs.filter.from")
    within ".flatpickr-calendar.fp-airbnb.open" do
      find(".flatpickr-day.today").click
      find(".flatpickr-day.today").click
    end
    today = Date.current
    assert_equal today.iso8601, find("input[name=from]", visible: :hidden).value
    assert_equal today.iso8601, find("input[name=to]", visible: :hidden).value
    assert_selector "[data-date-range-target=fromLabel]", text: today.strftime("%d.%m.%Y")

    click_button I18n.t("mail_logs.filter.submit")
    assert_text "Sichtbar Kind"
    assert_no_text "Altes Kind"
    assert_selector "[data-date-range-target=toLabel]", text: today.strftime("%d.%m.%Y")
  end
end
