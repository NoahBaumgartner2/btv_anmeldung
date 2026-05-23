class RefundService
  def self.process(registration)
    course = registration.course

    return { refunded: false, reason: "no_payment" } unless course.has_payment? && registration.payment_cleared?
    return { refunded: false, reason: "no_transaction_id" } unless registration.sumup_transaction_id.present?
    return { refunded: false, reason: "no_training_value" } unless course.training_value_cents.present? && course.training_value_cents > 0
    return { refunded: false, reason: "no_price" } unless course.price_cents.present? && course.price_cents > 0

    sessions_count = course.training_sessions
      .where(is_canceled: false)
      .where("start_time <= ?", Time.current)
      .where("start_time >= ?", registration.created_at)
      .count

    abzug_cents = sessions_count * course.training_value_cents
    refund_cents = course.price_cents - abzug_cents

    Rails.logger.info "[RefundService] Registration #{registration.id}: price=#{course.price_cents}¢, sessions=#{sessions_count}, abzug=#{abzug_cents}¢, refund=#{refund_cents}¢"

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

    Rails.logger.info "[RefundService] Rückerstattung CHF #{amount} für Registration #{registration.id} erfolgreich (txn: #{txn_id})"
    { refunded: true, amount_cents: refund_cents, sessions_count: sessions_count }

  rescue SocketError, Timeout::Error, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
    raise RuntimeError, "SumUp API nicht erreichbar: #{e.message}"
  end
end
