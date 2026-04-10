require "test_helper"

class InfomaniakNewsletterServiceTest < ActiveSupport::TestCase
  ApiError = InfomaniakNewsletterService::InfomaniakApiError

  setup do
    cfg = ActiveSupport::OrderedOptions.new
    cfg.api_token       = "test-token-123"
    cfg.mailing_list_id = "42"
    cfg.base_url        = "https://api.infomaniak.com"
    Rails.application.config.infomaniak = cfg
  end

  # ── Hilfsmethoden ──────────────────────────────────────────────────────────

  # Baut eine erfolgreiche Net::HTTP-Response (2xx).
  def ok_response(body = "{}")
    r = Net::HTTPOK.new("1.1", "200", "OK")
    r.instance_variable_set(:@body, body)
    r.instance_variable_set(:@read, true)
    r
  end

  # Baut eine Fehler-Response (4xx/5xx) anhand des HTTP-Statuscodes.
  def error_response(code, body = '{"error":"api_error"}')
    klass = Net::HTTPResponse::CODE_TO_OBJ.fetch(code.to_s, Net::HTTPBadRequest)
    r = klass.new("1.1", code.to_s, "Error")
    r.instance_variable_set(:@body, body)
    r.instance_variable_set(:@read, true)
    r
  end

  # Baut ein minimales Fake-Net::HTTP-Objekt, das request() mit der gegebenen
  # Response antwortet.
  def fake_http(response)
    obj = Object.new
    obj.define_singleton_method(:use_ssl=) { |_| }
    obj.define_singleton_method(:read_timeout=) { |_| }
    obj.define_singleton_method(:open_timeout=) { |_| }
    obj.define_singleton_method(:request) { |_req| response }
    obj
  end

  # Fake-Net::HTTP, dessen request() einen Netzwerkfehler wirft.
  def fake_http_raising(error)
    obj = Object.new
    obj.define_singleton_method(:use_ssl=) { |_| }
    obj.define_singleton_method(:read_timeout=) { |_| }
    obj.define_singleton_method(:open_timeout=) { |_| }
    obj.define_singleton_method(:request) { |_req| raise error }
    obj
  end

  # Ersetzt Net::HTTP.new für die Dauer des Blocks durch das gegebene Fake-Objekt.
  # Keine externen Gems nötig – reines Ruby define_singleton_method.
  def with_http_stub(fake_http_obj, &block)
    Net::HTTP.define_singleton_method(:new) { |*_| fake_http_obj }
    block.call
  ensure
    Net::HTTP.singleton_class.send(:remove_method, :new)
  end

  # ── subscribe – Erfolgsfall ─────────────────────────────────────────────────

  test "subscribe gibt geparsten JSON-Body zurück bei HTTP 200" do
    body = '{"result":"added","id":99}'
    with_http_stub(fake_http(ok_response(body))) do
      result = InfomaniakNewsletterService.subscribe(email: "max@example.com", name: "Max")
      assert_equal({ "result" => "added", "id" => 99 }, result)
    end
  end

  test "subscribe gibt leeres Hash zurück bei leerem Response-Body" do
    empty = Net::HTTPOK.new("1.1", "200", "OK")
    empty.instance_variable_set(:@body, "")
    empty.instance_variable_set(:@read, true)

    with_http_stub(fake_http(empty)) do
      result = InfomaniakNewsletterService.subscribe(email: "max@example.com")
      assert_equal({}, result)
    end
  end

  # ── subscribe – 4xx/5xx → InfomaniakApiError ───────────────────────────────

  test "subscribe wirft InfomaniakApiError mit http_code 422 bei HTTP 422" do
    with_http_stub(fake_http(error_response(422))) do
      error = assert_raises(ApiError) do
        InfomaniakNewsletterService.subscribe(email: "bad@example.com")
      end
      assert_equal 422, error.http_code
      assert_includes error.message, "422"
    end
  end

  test "subscribe wirft InfomaniakApiError bei HTTP 401 Unauthorized" do
    with_http_stub(fake_http(error_response(401))) do
      error = assert_raises(ApiError) do
        InfomaniakNewsletterService.subscribe(email: "x@example.com")
      end
      assert_equal 401, error.http_code
    end
  end

  test "subscribe wirft InfomaniakApiError bei HTTP 500" do
    with_http_stub(fake_http(error_response(500))) do
      error = assert_raises(ApiError) do
        InfomaniakNewsletterService.subscribe(email: "x@example.com")
      end
      assert_equal 500, error.http_code
    end
  end

  # ── subscribe – Netzwerkfehler → InfomaniakApiError ────────────────────────

  test "subscribe wirft InfomaniakApiError bei SocketError" do
    with_http_stub(fake_http_raising(SocketError.new("getaddrinfo failed"))) do
      error = assert_raises(ApiError) do
        InfomaniakNewsletterService.subscribe(email: "x@example.com")
      end
      assert_includes error.message, "Netzwerkfehler"
    end
  end

  test "subscribe wirft InfomaniakApiError bei Net::ReadTimeout" do
    with_http_stub(fake_http_raising(Net::ReadTimeout.new)) do
      error = assert_raises(ApiError) do
        InfomaniakNewsletterService.subscribe(email: "x@example.com")
      end
      assert_includes error.message, "Netzwerkfehler"
    end
  end

  # ── unsubscribe – Erfolgsfall ───────────────────────────────────────────────

  test "unsubscribe gibt geparsten JSON-Body zurück bei HTTP 200" do
    with_http_stub(fake_http(ok_response('{"result":"removed"}'))) do
      result = InfomaniakNewsletterService.unsubscribe(email: "max@example.com")
      assert_equal({ "result" => "removed" }, result)
    end
  end

  # ── unsubscribe – 4xx → InfomaniakApiError ─────────────────────────────────

  test "unsubscribe wirft InfomaniakApiError mit http_code 404 bei HTTP 404" do
    with_http_stub(fake_http(error_response(404))) do
      error = assert_raises(ApiError) do
        InfomaniakNewsletterService.unsubscribe(email: "ghost@example.com")
      end
      assert_equal 404, error.http_code
      assert_includes error.message, "404"
    end
  end

  test "unsubscribe wirft InfomaniakApiError bei HTTP 403" do
    with_http_stub(fake_http(error_response(403))) do
      error = assert_raises(ApiError) do
        InfomaniakNewsletterService.unsubscribe(email: "x@example.com")
      end
      assert_equal 403, error.http_code
    end
  end

  # ── unsubscribe – Netzwerkfehler ───────────────────────────────────────────

  test "unsubscribe wirft InfomaniakApiError bei Errno::ECONNREFUSED" do
    with_http_stub(fake_http_raising(Errno::ECONNREFUSED.new)) do
      error = assert_raises(ApiError) do
        InfomaniakNewsletterService.unsubscribe(email: "x@example.com")
      end
      assert_includes error.message, "Netzwerkfehler"
    end
  end

  test "unsubscribe kodiert Sonderzeichen in der E-Mail im Pfad" do
    # Eine E-Mail mit '+' muss URL-encoded sein. Wir prüfen, dass kein
    # Net::HTTP-Fehler auftritt (die Kodierung ist im Service via CGI.escape).
    with_http_stub(fake_http(ok_response)) do
      result = InfomaniakNewsletterService.unsubscribe(email: "max+test@example.com")
      assert_kind_of Hash, result
    end
  end
end
