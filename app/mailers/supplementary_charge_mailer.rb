class SupplementaryChargeMailer < ApplicationMailer
  # Erste Mail an die Eltern: Nachforderung + Zahlungslink + individueller
  # Erklärtext (warum wird nachträglich noch etwas verlangt).
  def payment_request(charge)
    @charge = charge
    @participant = charge.participant
    @course = charge.course
    @recipient = @participant.user
    return if @recipient.nil?

    return unless MailSetting.mail_enabled?(:supplementary_charge_request)

    @charge_url = supplementary_charge_url(@charge)

    mail(
      to: @recipient.email,
      subject: "Zusätzlicher Betrag für #{@participant.first_name}: #{@charge.amount_display}"
    )
  end

  # Offizielle Quittung nach erfolgter Zahlung.
  def receipt(charge)
    @charge = charge
    @participant = charge.participant
    @course = charge.course
    @recipient = @participant.user
    return if @recipient.nil?

    return unless MailSetting.mail_enabled?(:supplementary_charge_receipt)

    mail(
      to: @recipient.email,
      subject: "Quittung: #{@charge.description}"
    )
  end
end
