class RefundService
  # Berechnet den geplanten Rückerstattungsbetrag (in Rappen), ohne den
  # SumUp-Refund auszulösen. Gibt nil zurück, wenn keine Rückerstattung möglich/sinnvoll ist.
  def self.calculate_amount_cents(registration)
    course = registration.course
    return nil unless course.has_payment? && registration.payment_cleared?
    return nil unless course.training_value_cents.present? && course.training_value_cents > 0

    paid_cents = registration.applied_price_cents || course.price_cents
    return nil unless paid_cents.present? && paid_cents > 0

    refund_cents = paid_cents - deduction_cents(registration)
    refund_cents.positive? ? refund_cents : nil
  end

  # amount_cents: vom Trainer/Admin bestätigter Betrag; ohne Angabe gilt der berechnete.
  def self.process(registration, amount_cents: nil)
    return { refunded: false, reason: "already_refunded" } if registration.refund_already_processed?

    course = registration.course

    return { refunded: false, reason: "no_payment" } unless course.has_payment? && registration.payment_cleared?
    return { refunded: false, reason: "no_transaction_id" } unless registration.sumup_transaction_id.present?
    return { refunded: false, reason: "no_training_value" } unless course.training_value_cents.present? && course.training_value_cents > 0

    # Basis ist der tatsächlich verrechnete Preis (inkl. Rabatt) — es darf nie
    # mehr zurückerstattet werden, als bezahlt wurde.
    paid_cents = registration.applied_price_cents || course.price_cents
    return { refunded: false, reason: "no_price" } unless paid_cents.present? && paid_cents > 0

    sessions_count = attended_sessions_count(registration)
    abzug_cents = deduction_cents(registration)
    refund_cents = amount_cents || (paid_cents - abzug_cents)
    raise RuntimeError, "Betrag höher als die bezahlten CHF #{format('%.2f', paid_cents / 100.0)}" if refund_cents > paid_cents

    Rails.logger.info "[RefundService] Registration #{registration.id}: paid=#{paid_cents}¢, sessions=#{sessions_count}, abzug=#{abzug_cents}¢, refund=#{refund_cents}¢"

    if refund_cents <= 0
      return { refunded: false, reason: "no_amount_after_deduction", sessions_count: sessions_count, abzug_cents: abzug_cents }
    end

    txn_id = registration.sumup_transaction_id

    # Root Cause (siehe developer.sumup.com/api/transactions/refund): v0.1/me/refund/{id}
    # ist die veraltete Route und lieferte pauschal 409 "not refundable in its current
    # state", obwohl SumUp die Transaktion selbst als erstattbar auswies. Aktuelle,
    # dokumentierte Route: v1.0/merchants/{merchant_code}/payments/{id}/refunds.
    uri = URI("https://api.sumup.com/v1.0/merchants/#{SumupConfig.merchant_code}/payments/#{txn_id}/refunds")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 15

    request = Net::HTTP::Post.new(uri.path, {
      "Content-Type"  => "application/json",
      "Authorization" => "Bearer #{SumupConfig.access_token}"
    })
    # WICHTIG: Trotz offizieller SumUp-OpenAPI-Spec ("amount" als Franken-Dezimalzahl,
    # z.B. 5 = CHF 5.00) hat diese Route empirisch bestätigt in Rappen gerechnet
    # (ein Versuch mit amount: 125.0 für CHF 125.00 hat real nur CHF 1.25 erstattet –
    # exakt Faktor 100 zu wenig). Wir senden daher den vollen Rappen-Betrag als
    # Ganzzahl. Falls SumUp die Route künftig doch spec-konform auf Franken umstellt,
    # muss das hier erneut angepasst werden – die nächsten automatischen
    # Rückerstattungen bitte im SumUp-Dashboard gegenprüfen.
    request.body = { amount: refund_cents }.to_json

    response = http.request(request)

    # Laut offizieller SumUp-OpenAPI-Spec liefert dieser Endpunkt bei Erfolg 201
    # (Created) + leeren Body, nicht 200. 204 zusätzlich toleriert als Sicherheitsnetz.
    unless [ 200, 201, 204 ].include?(response.code.to_i)
      parsed     = (JSON.parse(response.body) rescue {})
      parsed     = {} unless parsed.is_a?(Hash)
      error_code = parsed["error_code"].presence
      message    = parsed["message"].presence || response.body.to_s.truncate(200)
      status     = response.code

      hint = refund_error_hint(status.to_i, error_code.to_s, message.to_s)

      details = "SumUp Refund API Fehler #{status}"
      details += " (error_code: #{error_code})" if error_code.present?
      details += ": #{message}"

      raise RuntimeError, "Mögliche Ursache: #{hint}\n\n#{details}"
    end

    registration.update_column(:refunded_at, Time.current) if registration.persisted?
    Rails.logger.info "[RefundService] Rückerstattung CHF #{(refund_cents / 100.0).round(2)} (#{refund_cents}¢) für Registration #{registration.id} erfolgreich (txn: #{txn_id})"
    { refunded: true, amount_cents: refund_cents, sessions_count: sessions_count }

  rescue SocketError, Timeout::Error, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
    raise RuntimeError, "SumUp API nicht erreichbar: #{e.message}"
  end

  # Übersetzt eine SumUp-Refund-Fehlerantwort in einen verständlichen Hinweis
  # für den Admin. Deckt die häufigsten 4xx-Ursachen ab; alles andere fällt
  # auf einen generischen Hinweis zurück. Die rohe Original-Meldung bleibt
  # zusätzlich erhalten (siehe process).
  def self.refund_error_hint(status, error_code, message)
    haystack = "#{error_code} #{message}".downcase

    if status == 404
      "Transaktion bei SumUp nicht gefunden – die Transaktions-ID ist evtl. ungültig oder gehört zu einem anderen Konto."
    elsif haystack.include?("balance") || haystack.include?("funds") || haystack.include?("guthaben")
      "Zu wenig Guthaben auf dem SumUp-Konto, um die Rückerstattung zu decken. Bitte Konto-Saldo prüfen oder manuell per e-Banking erstatten."
    elsif haystack.include?("already") && haystack.include?("refund")
      "Diese Transaktion wurde bereits (ganz oder teilweise) zurückerstattet."
    elsif status == 409 || haystack.include?("not refundable") || haystack.include?("not_refundable")
      "Die Transaktion ist im aktuellen Zustand nicht erstattbar (z. B. noch nicht abgerechnet, zu alt oder bereits erstattet). Bitte im SumUp-Dashboard prüfen und ggf. manuell per e-Banking erstatten."
    elsif status == 400
      "SumUp hat die Anfrage abgelehnt (ungültige Parameter, z. B. Betrag grösser als die ursprüngliche Transaktion)."
    else
      "Unbekannte Ursache – bitte die Transaktion im SumUp-Dashboard prüfen und manuell per e-Banking erstatten."
    end
  end

  # Anzahl bereits stattgefundener (nicht abgesagter) Trainings seit der Anmeldung.
  # Nach einem Kurswechsel zählen die Trainings im alten Kurs (beim Verschieben
  # festgehalten, siehe RegistrationMoveService) plus die im aktuellen Kurs seit
  # dem Wechsel - der alte Kurs kann inzwischen gelöscht sein.
  def self.attended_sessions_count(registration)
    registration.sessions_before_move + attended_sessions(registration).count
  end

  def self.attended_sessions(registration)
    registration.course.training_sessions
      .where(is_canceled: false)
      .where("start_time <= ?", Time.current)
      .where("start_time >= ?", registration.moved_at || registration.created_at)
      .where.not(id: registration.attendances.where.not(cancellation_reason: nil).select(:training_session_id))
  end

  # Alle Angaben für das Bestätigungs-Overlay. refundable: false + reason, wenn keine
  # automatische Rückerstattung möglich ist (gleiche Bedingungen wie process).
  def self.breakdown(registration)
    course = registration.course
    paid_cents = registration.applied_price_cents || course.price_cents
    reason =
      if registration.refund_already_processed? then "already_refunded"
      elsif !(course.has_payment? && registration.payment_cleared?) then "no_payment"
      elsif registration.sumup_transaction_id.blank? then "no_transaction_id"
      elsif course.training_value_cents.to_i <= 0 then "no_training_value"
      elsif paid_cents.to_i <= 0 then "no_price"
      end
    return { refundable: false, reason: reason } if reason

    sessions = attended_sessions(registration).order(:start_time).to_a
    counted = registration.sessions_before_move + sessions.size
    deduction = deduction_cents(registration)
    {
      refundable: true, paid_cents: paid_cents, training_value_cents: course.training_value_cents,
      course_past_count: course.training_sessions.where(is_canceled: false).where("start_time <= ?", Time.current).count,
      sessions: sessions, sessions_before_move: registration.sessions_before_move, counted_count: counted,
      billable_count: [ counted - 1, 0 ].max, deduction_cents: deduction,
      amount_cents: [ paid_cents - deduction, 0 ].max,
      attendance_by_session: registration.attendances.where(training_session_id: sessions.map(&:id)).pluck(:training_session_id, :status).to_h
    }
  end

  # Das erste besuchte Training ist kostenlos (Schnupper-Charakter) und mindert
  # die Rückerstattung NICHT – erst ab dem zweiten Training wird pro Training
  # der Trainingswert abgezogen.
  def self.deduction_cents(registration)
    billable_sessions = [ attended_sessions_count(registration) - 1, 0 ].max
    billable_sessions * registration.course.training_value_cents
  end

  private_class_method :deduction_cents, :attended_sessions
end
