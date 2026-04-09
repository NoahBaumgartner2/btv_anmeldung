class SumupWebhooksController < ActionController::Base
  skip_before_action :verify_authenticity_token

  def create
    payload = request.body.read

    begin
      event = JSON.parse(payload)
    rescue JSON::ParserError
      return render json: { error: "Invalid payload" }, status: :bad_request
    end

    Rails.logger.info "[SumupWebhook] Event empfangen: checkout_id=#{event['id']} status=#{event['status']}"

    # SumUp sendet keinen signierten Payload – der Status wird per API-Call
    # verifiziert, um manipulierte Webhook-Anfragen zu ignorieren.
    if event["status"] == "PAID" && event["id"].present?
      handle_checkout_paid(event["id"])
    else
      Rails.logger.info "[SumupWebhook] Event ignoriert (status: #{event['status'].inspect})"
    end

    render json: { received: true }
  end

  private

  def handle_checkout_paid(checkout_id)
    registration = CourseRegistration.find_by(sumup_checkout_id: checkout_id)

    unless registration
      Rails.logger.warn "[SumupWebhook] Keine CourseRegistration für checkout_id=#{checkout_id}"
      return
    end

    if registration.payment_cleared?
      Rails.logger.info "[SumupWebhook] Registration #{registration.id} bereits bezahlt – übersprungen"
      return
    end

    # Status per API-Call verifizieren (verhindert Manipulation durch gefälschte Webhooks)
    response = PaymentSyncService.send(:fetch_checkout, checkout_id)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "[SumupWebhook] API-Verifizierung fehlgeschlagen (#{response.code}) für checkout_id=#{checkout_id}"
      return
    end

    checkout = JSON.parse(response.body)

    unless checkout["status"] == "PAID"
      Rails.logger.warn "[SumupWebhook] Webhook-Status weicht von API ab (API: #{checkout['status']}) – abgebrochen"
      return
    end

    transaction_id = checkout.dig("transactions", 0, "id")

    PaymentSyncService.mark_paid!(registration,
                                  transaction_id: transaction_id,
                                  checkout_id:    checkout_id)

    Rails.logger.info "[SumupWebhook] Registration #{registration.id} erfolgreich abgeglichen (Status: #{registration.reload.status})"
  rescue => e
    Rails.logger.error "[SumupWebhook] Fehler bei handle_checkout_paid: #{e.class}: #{e.message}"
  end
end
