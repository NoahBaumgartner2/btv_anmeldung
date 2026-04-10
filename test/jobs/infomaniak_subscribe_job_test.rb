require "test_helper"

# Hilfsmethode zum Stub von Klassenmethoden ohne externe Gems.
# Kapselt define_singleton_method + Wiederherstellung im ensure.
module ServiceStubHelper
  def stub_service_method(service_class, method_name, callable)
    original = service_class.method(method_name)
    service_class.define_singleton_method(method_name) do |*args, **kwargs, &blk|
      callable.call(*args, **kwargs, &blk)
    end
    yield
  ensure
    service_class.define_singleton_method(method_name, original)
  end
end

class InfomaniakSubscribeJobTest < ActiveJob::TestCase
  include ServiceStubHelper

  ApiError = InfomaniakNewsletterService::InfomaniakApiError

  # ── perform ruft den Service auf ───────────────────────────────────────────

  test "ruft InfomaniakNewsletterService.subscribe mit email und name auf" do
    captured = {}
    stub = ->(email:, name: nil) { captured = { email: email, name: name }; {} }

    stub_service_method(InfomaniakNewsletterService, :subscribe, stub) do
      InfomaniakSubscribeJob.perform_now("max@example.com", name: "Max Muster")
    end

    assert_equal "max@example.com", captured[:email]
    assert_equal "Max Muster",      captured[:name]
  end

  test "ruft InfomaniakNewsletterService.subscribe ohne name auf wenn name nil" do
    captured = {}
    stub = ->(email:, name: nil) { captured = { email: email, name: name }; {} }

    stub_service_method(InfomaniakNewsletterService, :subscribe, stub) do
      InfomaniakSubscribeJob.perform_now("max@example.com")
    end

    assert_equal "max@example.com", captured[:email]
    assert_nil captured[:name]
  end

  # ── Retry bei InfomaniakApiError ───────────────────────────────────────────

  test "enqueued Retry-Job bei InfomaniakApiError (erster Fehlschlag)" do
    always_fail = ->(**_) { raise ApiError, "API nicht erreichbar" }

    stub_service_method(InfomaniakNewsletterService, :subscribe, always_fail) do
      assert_enqueued_with(job: InfomaniakSubscribeJob) do
        InfomaniakSubscribeJob.perform_now("retry@example.com")
      end
    end
  end

  test "kein Retry-Job bei unbekanntem StandardError" do
    always_fail = ->(**_) { raise RuntimeError, "unerwarteter Fehler" }

    stub_service_method(InfomaniakNewsletterService, :subscribe, always_fail) do
      assert_no_enqueued_jobs(only: InfomaniakSubscribeJob) do
        assert_raises(RuntimeError) do
          InfomaniakSubscribeJob.perform_now("noretry@example.com")
        end
      end
    end
  end
end

class InfomaniakUnsubscribeJobTest < ActiveJob::TestCase
  include ServiceStubHelper

  ApiError = InfomaniakNewsletterService::InfomaniakApiError

  # ── perform ruft den Service auf ───────────────────────────────────────────

  test "ruft InfomaniakNewsletterService.unsubscribe mit email auf" do
    captured_email = nil
    stub = ->(email:) { captured_email = email; {} }

    stub_service_method(InfomaniakNewsletterService, :unsubscribe, stub) do
      InfomaniakUnsubscribeJob.perform_now("max@example.com")
    end

    assert_equal "max@example.com", captured_email
  end

  # ── Retry bei InfomaniakApiError ───────────────────────────────────────────

  test "enqueued Retry-Job bei InfomaniakApiError" do
    always_fail = ->(email:) { raise ApiError, "API nicht erreichbar" }

    stub_service_method(InfomaniakNewsletterService, :unsubscribe, always_fail) do
      assert_enqueued_with(job: InfomaniakUnsubscribeJob) do
        InfomaniakUnsubscribeJob.perform_now("retry@example.com")
      end
    end
  end
end
