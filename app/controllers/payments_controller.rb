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

    redirect_to checkout["hosted_checkout_url"] || checkout["url"], allow_other_host: true
  rescue StandardError => e
    Rails.logger.error "[SumUp] Unexpected error: #{e.message}"
    redirect_to course_registration_path(@registration),
                alert: "Ein Fehler ist aufgetreten. Bitte versuche es später erneut."
  end

  def success
    checkout_id = params[:checkout_id]

    if checkout_id.present?
      @registration = CourseRegistration.find_by(sumup_checkout_id: checkout_id)

      if @registration && !@registration.payment_cleared?
        uri = URI("https://api.sumup.com/v0.1/checkouts/#{checkout_id}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Get.new(uri.path, {
          "Authorization" => "Bearer #{::SumupConfig.access_token}"
        })

        response = http.request(request)

        if response.is_a?(Net::HTTPSuccess)
          checkout = JSON.parse(response.body)

          if checkout["status"] == "PAID"
            course = @registration.course
            if course.max_participants.present?
              confirmed_count = course.course_registrations.where(status: "bestätigt").count
              new_status = confirmed_count >= course.max_participants ? "warteliste" : "bestätigt"
            else
              new_status = "bestätigt"
            end

            transaction_id = checkout.dig("transactions", 0, "id")

            @registration.update!(
              payment_cleared:     true,
              sumup_transaction_id: transaction_id,
              status:              new_status
            )
          end
        else
          Rails.logger.error "[SumUp] Status check error #{response.code}: #{response.body}"
        end
      end
    end
  end

  def cancel
    @registration = CourseRegistration.find_by(id: params[:registration_id])
  end
end
