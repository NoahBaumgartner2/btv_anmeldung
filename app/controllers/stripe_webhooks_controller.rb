class StripeWebhooksController < ActionController::Base
  skip_before_action :verify_authenticity_token

  def create
    payload    = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

    begin
      event = ::Stripe::Webhook.construct_event(
        payload, sig_header, ::StripeConfig.webhook_secret
      )
    rescue JSON::ParserError
      return render json: { error: "Invalid payload" }, status: :bad_request
    rescue ::Stripe::SignatureVerificationError
      return render json: { error: "Invalid signature" }, status: :bad_request
    end

    Rails.logger.info "[StripeWebhook] Event empfangen: #{event['type']} (id: #{event['id']})"

    case event["type"]
    when "checkout.session.completed"
      handle_checkout_completed(event["data"]["object"])
    else
      Rails.logger.info "[StripeWebhook] Event ignoriert: #{event['type']}"
    end

    render json: { received: true }
  end

  private

  def handle_checkout_completed(session)
    registration_id = session.dig("metadata", "course_registration_id")
    unless registration_id
      Rails.logger.warn "[StripeWebhook] checkout.session.completed ohne course_registration_id (session: #{session['id']})"
      return
    end

    registration = CourseRegistration.find_by(id: registration_id)
    unless registration
      Rails.logger.warn "[StripeWebhook] CourseRegistration #{registration_id} nicht gefunden"
      return
    end

    # Idempotenz: bereits verarbeitet → überspringen
    if registration.payment_cleared?
      Rails.logger.info "[StripeWebhook] Registration #{registration_id} bereits als bezahlt markiert – übersprungen"
      return
    end

    PaymentSyncService.mark_paid!(registration,
                                  payment_intent: session["payment_intent"],
                                  session_id:     session["id"])

    Rails.logger.info "[StripeWebhook] Registration #{registration_id} erfolgreich abgeglichen (Status: #{registration.reload.status})"
  rescue => e
    Rails.logger.error "[StripeWebhook] Fehler bei handle_checkout_completed: #{e.class}: #{e.message}"
  end
end
