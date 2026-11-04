require "test_helper"

class MailLogsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @trainer = trainers(:one)
    @mine = log("training_session.cancellation_notice", "Kurs A", 1, [ @trainer.id ], 2.days.ago,
                participant_name: "Max Muster", subject: "Geheimer Betreff", recipients: [ "eltern@example.com" ], audience: "parent")
    @older = log("course_registration.confirmation", "Kurs B", 2, [ @trainer.id ], 9.days.ago, participant_name: "Lea Beispiel", audience: "parent")
    @foreign = log("course_registration.confirmation", "Fremder Kurs", 3, [ trainers(:two).id ], 1.day.ago, participant_name: "Fremdes Kind", audience: "parent")
    @payment = log("payment_reminder.reminder", "Kurs A", 1, [ @trainer.id ], 1.day.ago, participant_name: "Zahl Kind", audience: "parent")
  end

  test "Trainer:in sieht nur eigene Mails, ohne Betreff und Adresse" do
    sign_in @trainer.user
    get mail_logs_path

    assert_response :success
    assert_match "Eltern von Max Muster", response.body
    assert_match "Eltern von Lea Beispiel", response.body
    assert_no_match "Fremdes Kind", response.body
    assert_no_match "Fremder Kurs", response.body
    assert_no_match "Zahl Kind", response.body
    assert_no_match "Geheimer Betreff", response.body
    assert_no_match "eltern@example.com", response.body
    assert_select "a[href=?]", mail_logs_path
  end

  test "Admin sieht alle Mails mit Betreff und Adresse" do
    sign_in users(:admin)
    get mail_logs_path

    %w[Fremdes\ Kind Zahl\ Kind Geheimer\ Betreff eltern@example.com].each { |text| assert_match text, response.body }
  end

  test "Eltern werden abgewiesen" do
    sign_in users(:parent_only)
    get mail_logs_path

    assert_redirected_to root_path
  end

  test "Sortierung nach neuste und älteste" do
    sign_in @trainer.user

    get mail_logs_path
    assert_operator response.body.index("Max Muster"), :<, response.body.index("Lea Beispiel")

    get mail_logs_path(sort: "oldest")
    assert_operator response.body.index("Lea Beispiel"), :<, response.body.index("Max Muster")
  end

  test "Filter nach Kurs, Art und Datum" do
    sign_in @trainer.user

    get mail_logs_path(course_id: 2)
    assert_match "Lea Beispiel", response.body
    assert_no_match "Max Muster", response.body

    get mail_logs_path(kind: "training_session.cancellation_notice")
    assert_match "Max Muster", response.body
    assert_no_match "Lea Beispiel", response.body

    get mail_logs_path(from: 3.days.ago.to_date.iso8601)
    assert_match "Max Muster", response.body
    assert_no_match "Lea Beispiel", response.body

    get mail_logs_path(to: 3.days.ago.to_date.iso8601)
    assert_match "Lea Beispiel", response.body
    assert_no_match "Max Muster", response.body

    get mail_logs_path(from: "kein-datum")
    assert_response :success
  end

  test "fremder Kurs bleibt auch per Filter und Suche verborgen" do
    sign_in @trainer.user

    get mail_logs_path(course_id: 3)
    assert_no_match "Fremdes Kind", response.body
    assert_select "option", text: "Fremder Kurs", count: 0

    get mail_logs_path(q: "Fremdes")
    assert_no_match "Fremdes Kind", response.body
  end

  test "Suche: Trainer:in nur nach Name und Kurs, Admin auch nach Adresse" do
    sign_in @trainer.user
    get mail_logs_path(q: "eltern@example.com")
    assert_no_match "Max Muster", response.body
    get mail_logs_path(q: "max")
    assert_match "Max Muster", response.body
    get mail_logs_path(q: "100%")
    assert_response :success

    sign_out @trainer.user
    sign_in users(:admin)
    get mail_logs_path(q: "eltern@example.com")
    assert_match "Max Muster", response.body
  end

  test "zeigt 20 Mails und lädt mit Mehr anzeigen weitere" do
    51.times { |i| log("course_registration.confirmation", "Viele", 9, [ @trainer.id ], (i + 20).days.ago, participant_name: "Kind #{i}", audience: "parent") }
    sign_in @trainer.user

    get mail_logs_path(course_id: 9)
    assert_select "ul li", 20
    assert_match "20 von 51 Mails", response.body
    assert_select "a[href*='course_id=9'][href*='page=2'][href$='#mail-20']", text: "Mehr anzeigen"

    get mail_logs_path(course_id: 9, page: 2)
    assert_select "ul li", 40
    assert_select "li#mail-20"

    get mail_logs_path(course_id: 9, page: 3)
    assert_select "ul li", 51
    assert_match "51 Mails", response.body
    assert_select "a", text: "Mehr anzeigen", count: 0

    get mail_logs_path(course_id: 9, page: 999)
    assert_select "ul li", 51
  end

  private

  def log(kind, title, course_id, trainer_ids, at, **attrs)
    MailLog.create!(kind: kind, course_title: title, course_id: course_id, trainer_ids: trainer_ids, created_at: at, **attrs)
  end
end
