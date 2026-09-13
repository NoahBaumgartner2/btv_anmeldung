# Bezahlseite für Nachforderungen (siehe SupplementaryCharge). Spiegelt den
# SumUp-Checkout-Ablauf von PaymentsController, aber unabhängig von
# CourseRegistration/PaymentSyncService - eine Nachforderung hat keinen
# Warteliste-/Abo-Status, nur offen/bezahlt/storniert.
class SupplementaryChargesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_charge
  before_action :authorize_owner!

  def show
  end

  def checkout
    unless @charge.payable?
      return redirect_to supplementary_charge_path(@charge), notice: "Diese Nachforderung wurde bereits erledigt."
    end

    unless ::SumupConfig.configured?
      return redirect_to supplementary_charge_path(@charge),
        alert: "Zahlung aktuell nicht verfügbar. Bitte kontaktiere uns."
    end

    ::SumupConfig.ensure_valid_token!

    amount = (@charge.amount_cents / 100.0).round(2)
    body = {
      amount:             amount,
      currency:           ::SumupConfig.currency.upcase,
      checkout_reference: "supcharge-#{@charge.id}-#{Time.current.to_i}",
      merchant_code:      ::SumupConfig.merchant_code,
      description:        "#{@charge.description} – #{@charge.participant.first_name} #{@charge.participant.last_name} (#{@charge.course.title})",
      redirect_url:       success_supplementary_charge_url(@charge),
      hosted_checkout:    { enabled: true }
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
      Rails.logger.error "[SumUp] SupplementaryCharge-Checkout error #{response.code}: #{response.body}"
      return redirect_to supplementary_charge_path(@charge),
        alert: "Zahlung konnte nicht gestartet werden. Bitte versuche es später erneut."
    end

    checkout = JSON.parse(response.body)
    @charge.update!(sumup_checkout_id: checkout["id"])

    checkout_url = checkout.dig("hosted_checkout", "url") || checkout["hosted_checkout_url"]
    unless checkout_url.present?
      Rails.logger.error "[SumUp] SupplementaryCharge-Checkout ohne URL: #{checkout.inspect}"
      return redirect_to supplementary_charge_path(@charge),
        alert: "Zahlung konnte nicht gestartet werden. Bitte versuche es später erneut."
    end

    redirect_to checkout_url, allow_other_host: true
  rescue StandardError => e
    Rails.logger.error "[SumUp] SupplementaryCharge-Checkout Unexpected error: #{e.message}"
    redirect_to supplementary_charge_path(@charge), alert: "Ein Fehler ist aufgetreten. Bitte versuche es später erneut."
  end

  def success
    unless @charge.paid?
      if @charge.sumup_checkout_id.present?
        response = PaymentSyncService.fetch_checkout(@charge.sumup_checkout_id)
        if response.is_a?(Net::HTTPSuccess)
          checkout = JSON.parse(response.body)
          if checkout["status"] == "PAID"
            transaction_id = checkout.dig("transactions", 0, "id")
            @charge.update!(status: "bezahlt", sumup_transaction_id: transaction_id, paid_at: Time.current)
            SupplementaryChargeMailer.receipt(@charge).deliver_later
          end
        else
          Rails.logger.error "[SumUp] SupplementaryCharge status check error #{response.code}: #{response.body}"
        end
      end
    end

    @charge.reload
    if @charge.paid?
      redirect_to supplementary_charge_path(@charge), notice: "Deine Zahlung wurde erfolgreich verarbeitet."
    else
      redirect_to supplementary_charge_path(@charge), alert: "Die Zahlung wurde nicht abgeschlossen. Bitte versuche es erneut."
    end
  rescue StandardError => e
    Rails.logger.error "[SumUp] SupplementaryCharge success callback error: #{e.class}: #{e.message}"
    redirect_to supplementary_charge_path(@charge), alert: "Beim Verarbeiten der Zahlung ist ein Fehler aufgetreten."
  end

  private

  def set_charge
    @charge = SupplementaryCharge.find(params[:id])
  end

  def authorize_owner!
    unless current_user.participants.include?(@charge.participant) || current_user.admin?
      redirect_to root_path, alert: "Zugriff verweigert."
    end
  end
end
