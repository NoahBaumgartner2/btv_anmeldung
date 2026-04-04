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

    case event["type"]
    when "checkout.session.completed"
      handle_checkout_completed(event["data"]["object"])
    end

    render json: { received: true }
  end

  private

  def handle_checkout_completed(session)
    registration_id = session.dig("metadata", "course_registration_id")
    return unless registration_id

    registration = CourseRegistration.find_by(id: registration_id)
    return unless registration

    course = registration.course
    if course.max_participants.present?
      confirmed_count = course.course_registrations.where(status: "bestätigt").count
      new_status = confirmed_count >= course.max_participants ? "warteliste" : "bestätigt"
    else
      new_status = "bestätigt"
    end

    registration.update!(
      payment_cleared:          true,
      stripe_payment_intent_id: session["payment_intent"],
      stripe_session_id:        session["id"],
      status:                   new_status
    )
  rescue => e
    Rails.logger.error "[StripeWebhook] handle_checkout_completed error: #{e.message}"
  end
end
