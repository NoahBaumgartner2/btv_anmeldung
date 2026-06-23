class RefundService
  # Berechnet den geplanten Rückerstattungsbetrag (in Rappen), ohne den
  # SumUp-Refund auszulösen. Gibt nil zurück, wenn keine Rückerstattung möglich/sinnvoll ist.
  def self.calculate_amount_cents(registration)
    course = registration.course
    return nil unless course.has_payment? && registration.payment_cleared?
    return nil unless course.training_value_cents.present? && course.training_value_cents > 0

    paid_cents = registration.applied_price_cents || course.price_cents
    return nil unless paid_cents.present? && paid_cents > 0

    sessions_count = course.training_sessions
      .where(is_canceled: false)
      .where("start_time <= ?", Time.current)
      .where("start_time >= ?", registration.created_at)
      .count

    refund_cents = paid_cents - (sessions_count * course.training_value_cents)
    refund_cents.positive? ? refund_cents : nil
  end

  def self.process(registration)
    return { refunded: false, reason: "already_refunded" } if registration.refund_already_processed?

    course = registration.course

    return { refunded: false, reason: "no_payment" } unless course.has_payment? && registration.payment_cleared?
    return { refunded: false, reason: "no_transaction_id" } unless registration.sumup_transaction_id.present?
    return { refunded: false, reason: "no_training_value" } unless course.training_value_cents.present? && course.training_value_cents > 0

    # Basis ist der tatsächlich verrechnete Preis (inkl. Rabatt) — es darf nie
    # mehr zurückerstattet werden, als bezahlt wurde.
    paid_cents = registration.applied_price_cents || course.price_cents
    return { refunded: false, reason: "no_price" } unless paid_cents.present? && paid_cents > 0

    sessions_count = course.training_sessions
      .where(is_canceled: false)
      .where("start_time <= ?", Time.current)
      .where("start_time >= ?", registration.created_at)
      .count

    abzug_cents = sessions_count * course.training_value_cents
    refund_cents = paid_cents - abzug_cents

    Rails.logger.info "[RefundService] Registration #{registration.id}: paid=#{paid_cents}¢, sessions=#{sessions_count}, abzug=#{abzug_cents}¢, refund=#{refund_cents}¢"

    if refund_cents <= 0
      return { refunded: false, reason: "no_amount_after_deduction", sessions_count: sessions_count, abzug_cents: abzug_cents }
    end

    amount = (refund_cents / 100.0).round(2)
    txn_id = registration.sumup_transaction_id

    uri = URI("https://api.sumup.com/v0.1/me/refund/#{txn_id}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 15

    request = Net::HTTP::Post.new(uri.path, {
      "Content-Type"  => "application/json",
      "Authorization" => "Bearer #{SumupConfig.access_token}"
    })
    request.body = { amount: amount }.to_json

    response = http.request(request)

    unless response.code.to_i == 204
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
    Rails.logger.info "[RefundService] Rückerstattung CHF #{amount} für Registration #{registration.id} erfolgreich (txn: #{txn_id})"
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
end
