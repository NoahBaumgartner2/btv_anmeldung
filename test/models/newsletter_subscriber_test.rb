require "test_helper"

class NewsletterSubscriberTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # ── Neuer Subscriber → Subscribe-Job ───────────────────────────────────────

  test "neuer Subscriber mit status subscribed enqueued InfomaniakSubscribeJob" do
    assert_enqueued_with(job: InfomaniakSubscribeJob) do
      NewsletterSubscriber.create!(email: "neu@example.com", status: "subscribed")
    end
  end

  test "neuer Subscriber mit name enqueued Job mit korrekter E-Mail" do
    # Prüft, dass die normalisierte (lowercase) E-Mail im Job landet.
    assert_enqueued_with(job: InfomaniakSubscribeJob, args: [ "gross@example.com", { name: "Anna" } ]) do
      NewsletterSubscriber.create!(email: "GROSS@example.com", status: "subscribed", name: "Anna")
    end
  end

  test "neuer Subscriber mit status unsubscribed enqueued keinen Subscribe-Job" do
    assert_no_enqueued_jobs(only: InfomaniakSubscribeJob) do
      NewsletterSubscriber.create!(email: "unsub@example.com", status: "unsubscribed")
    end
  end

  # ── Status-Wechsel → Unsubscribe-Job ───────────────────────────────────────

  test "Status-Wechsel subscribed → unsubscribed enqueued InfomaniakUnsubscribeJob" do
    subscriber = NewsletterSubscriber.create!(email: "wechsel@example.com", status: "subscribed")
    clear_enqueued_jobs

    assert_enqueued_with(job: InfomaniakUnsubscribeJob, args: [ "wechsel@example.com" ]) do
      subscriber.update!(status: "unsubscribed")
    end
  end

  test "Status-Wechsel subscribed → unsubscribed enqueued keinen Subscribe-Job" do
    subscriber = NewsletterSubscriber.create!(email: "wechsel2@example.com", status: "subscribed")
    clear_enqueued_jobs

    assert_no_enqueued_jobs(only: InfomaniakSubscribeJob) do
      subscriber.update!(status: "unsubscribed")
    end
  end

  test "Status-Wechsel unsubscribed → subscribed enqueued InfomaniakSubscribeJob" do
    subscriber = NewsletterSubscriber.create!(email: "reaktiv@example.com", status: "unsubscribed")
    clear_enqueued_jobs

    assert_enqueued_with(job: InfomaniakSubscribeJob) do
      subscriber.update!(status: "subscribed")
    end
  end

  # ── Save ohne Status/Email/Name-Änderung → kein Job ───────────────────────

  test "Update von source enqueued keinen Job" do
    subscriber = NewsletterSubscriber.create!(email: "quelle@example.com", status: "subscribed", source: "manual")
    clear_enqueued_jobs

    assert_no_enqueued_jobs do
      subscriber.update!(source: "csv_import")
    end
  end

  test "touch (updated_at) enqueued keinen Job" do
    subscriber = NewsletterSubscriber.create!(email: "touch@example.com", status: "subscribed")
    clear_enqueued_jobs

    assert_no_enqueued_jobs do
      subscriber.touch
    end
  end

  # ── Validierungen ──────────────────────────────────────────────────────────

  test "ungültige E-Mail ist invalid" do
    sub = NewsletterSubscriber.new(email: "kein-at-zeichen", status: "subscribed")
    assert_not sub.valid?
    assert_includes sub.errors[:email], I18n.t("errors.messages.invalid")
  end

  test "doppelte E-Mail (case-insensitive) ist invalid" do
    NewsletterSubscriber.create!(email: "doppelt@example.com", status: "subscribed")
    duplicate = NewsletterSubscriber.new(email: "DOPPELT@example.com", status: "subscribed")
    assert_not duplicate.valid?
    assert sub_errors_on?(duplicate, :email)
  end

  test "ungültiger Status ist invalid" do
    sub = NewsletterSubscriber.new(email: "x@example.com", status: "pending")
    assert_not sub.valid?
    assert_includes sub.errors[:status], I18n.t("errors.messages.inclusion")
  end

  private

  def sub_errors_on?(record, attribute)
    record.errors[attribute].any?
  end
end
