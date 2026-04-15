# Kapselt alle HTTP-Aufrufe an die Infomaniak Newsletter REST API.
# Konfiguration kommt aus Rails.application.config.infomaniak (gesetzt in
# config/initializers/infomaniak.rb).
#
# Verwendung:
#   InfomaniakNewsletterService.subscribe(email: "max@example.com", name: "Max")
#   InfomaniakNewsletterService.unsubscribe(email: "max@example.com")
class InfomaniakNewsletterService
  class InfomaniakApiError < StandardError
    attr_reader :http_code, :body

    def initialize(message, http_code: nil, body: nil)
      super(message)
      @http_code = http_code
      @body      = body
    end
  end

  # ---------------------------------------------------------------------------
  # TODO: Endpunkte nach Lektüre der offiziellen Infomaniak API-Dokumentation
  # verifizieren und ggf. anpassen:
  #   https://developer.infomaniak.com/docs/api
  #
  # Aktuell genutzte Platzhalter-Pfade (relativ zu base_url):
  #   POST   /1/newsletters/{mailing_list_id}/subscribers   → subscribe
  #   DELETE /1/newsletters/{mailing_list_id}/subscribers/{encoded_email} → unsubscribe
  #
  # Mögliche Abweichungen, die zu prüfen sind:
  #   - Heisst der Body-Key für die E-Mail tatsächlich "email"? (evtl. "address")
  #   - Heisst der Body-Key für den Namen "name"? (evtl. "firstname"/"lastname")
  #   - Muss beim Unsubscribe die E-Mail im Pfad URL-encoded übergeben werden?
  #   - Gibt es einen separaten "unsubscribe"-Endpoint (POST) statt DELETE?
  # ---------------------------------------------------------------------------

  SUBSCRIBER_PATH  = "/1/newsletters/%<list_id>s/subscribers"
  SUBSCRIBER_PATH_WITH_EMAIL = "/1/newsletters/%<list_id>s/subscribers/%<email>s"

  # Fügt eine E-Mail zur konfigurierten Mailingliste hinzu.
  #
  # @param email [String] E-Mail-Adresse des Abonnenten
  # @param name  [String, nil] Optionaler Anzeigename
  # @raise [InfomaniakApiError] bei HTTP 4xx/5xx oder Netzwerkfehler
  def self.subscribe(email:, name: nil)
    # TODO: Body-Felder gemäss API-Doku anpassen (z.B. "firstname"/"lastname" statt "name")
    body = { email: email }
    body[:name] = name if name.present?

    path = format(SUBSCRIBER_PATH, list_id: config.mailing_list_id)

    response = request(:post, path, body)
    Rails.logger.info "[InfomaniakNewsletter] subscribe erfolgreich: #{email} " \
                      "(HTTP #{response.code})"
    parse_body(response)
  rescue InfomaniakApiError
    raise
  rescue SocketError, Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET,
         Errno::EHOSTUNREACH, Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error "[InfomaniakNewsletter] subscribe Netzwerkfehler für #{email}: " \
                       "#{e.class}: #{e.message}"
    raise InfomaniakApiError, "Netzwerkfehler beim Eintragen von #{email}: #{e.message}"
  end

  # Trägt eine E-Mail aus der konfigurierten Mailingliste aus.
  #
  # @param email [String] E-Mail-Adresse des Abonnenten
  # @raise [InfomaniakApiError] bei HTTP 4xx/5xx oder Netzwerkfehler
  def self.unsubscribe(email:)
    # TODO: Prüfen ob Infomaniak DELETE + E-Mail im Pfad nutzt oder einen
    #       POST /subscribers/unsubscribe Endpunkt anbietet.
    encoded_email = CGI.escape(email)
    path = format(SUBSCRIBER_PATH_WITH_EMAIL, list_id: config.mailing_list_id, email: encoded_email)

    response = request(:delete, path)
    Rails.logger.info "[InfomaniakNewsletter] unsubscribe erfolgreich: #{email} " \
                      "(HTTP #{response.code})"
    parse_body(response)
  rescue InfomaniakApiError
    raise
  rescue SocketError, Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET,
         Errno::EHOSTUNREACH, Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error "[InfomaniakNewsletter] unsubscribe Netzwerkfehler für #{email}: " \
                       "#{e.class}: #{e.message}"
    raise InfomaniakApiError, "Netzwerkfehler beim Austragen von #{email}: #{e.message}"
  end

  # ---------------------------------------------------------------------------
  # Private Hilfsmethoden
  # ---------------------------------------------------------------------------

  def self.config
    Rails.application.config.infomaniak
  end
  private_class_method :config

  # Führt einen HTTP-Request durch und gibt das Net::HTTPResponse-Objekt zurück.
  # Wirft InfomaniakApiError bei 4xx/5xx.
  def self.request(method, path, body = nil)
    base = config.base_url.chomp("/")
    uri  = URI("#{base}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl     = uri.scheme == "https"
    http.read_timeout = 10
    http.open_timeout = 5

    req = build_request(method, uri, body)
    response = http.request(req)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "[InfomaniakNewsletter] API-Fehler #{response.code} " \
                         "für #{method.upcase} #{path}: #{response.body.truncate(200)}"
      raise InfomaniakApiError.new(
        "Infomaniak API antwortete mit HTTP #{response.code}",
        http_code: response.code.to_i,
        body:      response.body
      )
    end

    response
  end
  private_class_method :request

  def self.build_request(method, uri, body)
    klass = case method
            when :post   then Net::HTTP::Post
            when :delete then Net::HTTP::Delete
            when :get    then Net::HTTP::Get
            else raise ArgumentError, "Unbekannte HTTP-Methode: #{method}"
            end

    req = klass.new(uri.request_uri)
    req["Authorization"] = "Bearer #{config.api_token}"
    req["Accept"]        = "application/json"

    if body
      req["Content-Type"] = "application/json"
      req.body = body.to_json
    end

    req
  end
  private_class_method :build_request

  # Parst den JSON-Body der Response; gibt leeres Hash zurück bei leerem Body.
  def self.parse_body(response)
    return {} if response.body.blank?

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    Rails.logger.warn "[InfomaniakNewsletter] Antwort ist kein valides JSON: #{e.message}"
    {}
  end
  private_class_method :parse_body
end
