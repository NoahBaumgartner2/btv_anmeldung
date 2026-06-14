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
      error_msg = begin
        JSON.parse(response.body)["message"]
      rescue
        response.body.to_s.truncate(200)
      end
      raise RuntimeError, "SumUp Refund API Fehler #{response.code}: #{error_msg}"
    end

    registration.update_column(:refunded_at, Time.current) if registration.persisted?
    Rails.logger.info "[RefundService] Rückerstattung CHF #{amount} für Registration #{registration.id} erfolgreich (txn: #{txn_id})"
    { refunded: true, amount_cents: refund_cents, sessions_count: sessions_count }

  rescue SocketError, Timeout::Error, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
    raise RuntimeError, "SumUp API nicht erreichbar: #{e.message}"
  end
end
