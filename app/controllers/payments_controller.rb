class PaymentsController < ApplicationController
  before_action :authenticate_user!

  def checkout
    @registration = CourseRegistration.find(params[:id])

    unless current_user.participants.include?(@registration.participant) || current_user.admin?
      return redirect_to root_path, alert: "Zugriff verweigert."
    end

    course = @registration.course

    unless course.has_payment? && course.price_cents.present?
      return redirect_to course_registration_path(@registration),
                         alert: "Dieser Kurs erfordert keine Zahlung."
    end

    if @registration.payment_cleared?
      return redirect_to course_registration_path(@registration),
                         notice: "Dieser Kurs wurde bereits bezahlt."
    end

    unless ::StripeConfig.configured?
      return redirect_to course_registration_path(@registration),
                         alert: "Zahlung aktuell nicht verfügbar. Bitte kontaktiere uns."
    end

    ::Stripe.api_key = ::StripeConfig.secret_key

    stripe_session = ::Stripe::Checkout::Session.create(
      payment_method_types: ["card"],
      line_items: [{
        price_data: {
          currency:     ::StripeConfig.currency,
          unit_amount:  course.price_cents,
          product_data: {
            name:        course.title,
            description: "#{course.registration_type} – #{course.location.presence || 'BTV'}"
          }
        },
        quantity: 1
      }],
      mode:        "payment",
      success_url: payments_success_url(session_id: "{CHECKOUT_SESSION_ID}"),
      cancel_url:  payments_cancel_url(registration_id: @registration.id),
      metadata:    { course_registration_id: @registration.id },
      customer_email: current_user.email
    )

    @registration.update!(stripe_session_id: stripe_session.id)

    redirect_to stripe_session.url, allow_other_host: true
  rescue ::Stripe::StripeError => e
    Rails.logger.error "[Stripe] Checkout error: #{e.message}"
    redirect_to course_registration_path(@registration),
                alert: "Stripe-Fehler: #{e.message}"
  end

  def success
    session_id = params[:session_id]

    if session_id.present?
      @registration = CourseRegistration.find_by(stripe_session_id: session_id)

      if @registration && !@registration.payment_cleared?
        ::Stripe.api_key = ::StripeConfig.secret_key
        stripe_session = ::Stripe::Checkout::Session.retrieve(session_id)

        if stripe_session.payment_status == "paid"
          course = @registration.course
          if course.max_participants.present?
            confirmed_count = course.course_registrations.where(status: "bestätigt").count
            new_status = confirmed_count >= course.max_participants ? "warteliste" : "bestätigt"
          else
            new_status = "bestätigt"
          end

          @registration.update!(
            payment_cleared:          true,
            stripe_payment_intent_id: stripe_session.payment_intent,
            status:                   new_status
          )
        end
      end
    end
  end

  def cancel
    @registration = CourseRegistration.find_by(id: params[:registration_id])
  end
end
