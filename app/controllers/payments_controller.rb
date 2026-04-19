class PaymentsController < ApplicationController
  before_action :authenticate_user!

  def checkout_preview
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

    unless ::SumupConfig.configured?
      return redirect_to course_registration_path(@registration),
                         alert: "Zahlung aktuell nicht verfügbar. Bitte kontaktiere uns."
    end
  end

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

    unless ::SumupConfig.configured?
      return redirect_to course_registration_path(@registration),
                         alert: "Zahlung aktuell nicht verfügbar. Bitte kontaktiere uns."
    end

    amount = (course.price_cents / 100.0).round(2)

    body = {
      amount:             amount,
      currency:           ::SumupConfig.currency.upcase,
      checkout_reference: @registration.id.to_s,
      merchant_code:      ::SumupConfig.merchant_code,
      description:        "#{course.title} – #{course.registration_type}",
      return_url:         payments_success_url(checkout_id: "{checkout_id}")
    }

    uri = URI("https://api.sumup.com/v0.1/checkouts")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.path, {
      "Content-Type"  => "application/json",
      "Authorization" => "Bearer #{::SumupConfig.access_token}"
    })
    request.body = body.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "[SumUp] Checkout error #{response.code}: #{response.body}"
      return redirect_to course_registration_path(@registration),
                         alert: "Zahlung konnte nicht gestartet werden. Bitte versuche es später erneut."
    end

    checkout = JSON.parse(response.body)
    @registration.update!(sumup_checkout_id: checkout["id"])

    checkout_url = checkout["hosted_checkout_url"] || checkout["url"]
    unless checkout_url.present?
      Rails.logger.error "[SumUp] Checkout response enthält keine URL: #{checkout.inspect}"
      return redirect_to course_registration_path(@registration),
                         alert: "Zahlung konnte nicht gestartet werden. Bitte versuche es später erneut."
    end

    redirect_to checkout_url, allow_other_host: true
  rescue StandardError => e
    Rails.logger.error "[SumUp] Unexpected error: #{e.message}"
    redirect_to course_registration_path(@registration),
                alert: "Ein Fehler ist aufgetreten. Bitte versuche es später erneut."
  end

  def success
    checkout_id = params[:checkout_id]

    unless checkout_id.present?
      return redirect_to root_path, alert: "Zahlung nicht gefunden."
    end

    @registration = CourseRegistration.find_by(sumup_checkout_id: checkout_id)

    unless @registration
      return redirect_to root_path, alert: "Zahlung nicht gefunden."
    end

    unless @registration.payment_cleared?
      response = PaymentSyncService.fetch_checkout(checkout_id)

      if response.is_a?(Net::HTTPSuccess)
        checkout = JSON.parse(response.body)

        if checkout["status"] == "PAID"
          transaction_id = checkout.dig("transactions", 0, "id")
          PaymentSyncService.mark_paid!(@registration, transaction_id: transaction_id, checkout_id: checkout_id)
        end
      else
        Rails.logger.error "[SumUp] Status check error #{response.code}: #{response.body}"
      end
    end

    redirect_to course_registration_path(@registration), notice: "Deine Zahlung wurde erfolgreich verarbeitet."
  rescue StandardError => e
    Rails.logger.error "[SumUp] success callback error: #{e.class}: #{e.message}"
    if @registration
      redirect_to course_registration_path(@registration),
                  notice: "Deine Zahlung wird möglicherweise noch verarbeitet. Bitte lade die Seite in einigen Minuten neu."
    else
      redirect_to root_path,
                  alert: "Ein Fehler ist aufgetreten. Bitte kontaktiere uns falls deine Zahlung nicht verarbeitet wurde."
    end
  end

  def cancel
    @registration = CourseRegistration.find_by(id: params[:registration_id])
  end
end
