require "base64"

class CourseRegistrationMailer < ApplicationMailer
  def confirmation(course_registration)
    @course_registration = course_registration
    @course = course_registration.course
    @participant = course_registration.participant
    @recipient = @participant.user
    return if @recipient.nil?

    if ["bestätigt", "schnuppern"].include?(course_registration.status) && @course.has_ticketing?
      qr = RQRCode::QRCode.new(scan_course_registration_url(course_registration))
      png = qr.as_png(
        bit_depth: 1,
        border_modules: 4,
        color_mode: ChunkyPNG::COLOR_GRAYSCALE,
        color: "black",
        file: nil,
        fill: "white",
        module_px_size: 6,
        resize_exactly_to: nil,
        resize_gte_to: nil,
        size: 240
      )
      @qr_code_base64 = Base64.strict_encode64(png.to_s)
    end

    subject = case course_registration.status
    when "bestätigt"  then "Anmeldung bestätigt: #{@course.title}"
    when "warteliste" then "Auf der Warteliste: #{@course.title}"
    when "schnuppern" then "Schnupperplatz gesichert: #{@course.title}"
    else "Anmeldung erhalten: #{@course.title}"
    end

    mail(to: @recipient.email, subject: subject)
  end

  def waitlist_promoted(course_registration)
    @course_registration = course_registration
    @course = course_registration.course
    @participant = course_registration.participant
    @recipient = @participant.user
    return if @recipient.nil?

    mail(
      to: @recipient.email,
      subject: "Du hast einen Platz erhalten: #{@course.title}"
    )
  end

  def cancelled_by_trainer(course_registration)
    @course_registration = course_registration
    @course       = course_registration.course
    @participant  = course_registration.participant
    @recipient    = @participant.user
    return if @recipient.nil?

    @reason       = course_registration.cancellation_reason
    @cancelled_by = course_registration.cancelled_by_trainer&.user&.email

    mail(
      to: @recipient.email,
      subject: "Abmeldung vom Kurs: #{@course.title}"
    )
  end

  def admin_refund_notice(course_registration, admin_user)
    @course_registration = course_registration
    @course       = course_registration.course
    @participant  = course_registration.participant
    @parent       = @participant.user
    @reason       = course_registration.cancellation_reason
    @cancelled_by = course_registration.cancelled_by_trainer&.user&.email
    @recipient    = admin_user

    mail(
      to: admin_user.email,
      subject: "Rückerstattung prüfen: #{@participant.first_name} #{@participant.last_name} (#{@course.title})"
    )
  end

  def payment_expired(course_registration)
    @course_registration = course_registration
    @course = course_registration.course
    @participant = course_registration.participant
    @recipient = @participant.user
    return if @recipient.nil?

    mail(
      to: @recipient.email,
      subject: "Reservierung abgelaufen: #{@course.title}"
    )
  end

  def payment_receipt(course_registration)
    @course_registration = course_registration
    @course = course_registration.course
    @participant = course_registration.participant
    @recipient = @participant.user
    return if @recipient.nil?

    @paid_at = course_registration.updated_at
    @transaction_id = course_registration.sumup_transaction_id
    @checkout_id = course_registration.sumup_checkout_id

    if @course.has_ticketing?
      qr = RQRCode::QRCode.new(scan_course_registration_url(@course_registration))
      png = qr.as_png(
        bit_depth: 1,
        border_modules: 4,
        color_mode: ChunkyPNG::COLOR_GRAYSCALE,
        color: "black",
        file: nil,
        fill: "white",
        module_px_size: 6,
        resize_exactly_to: nil,
        resize_gte_to: nil,
        size: 240
      )
      @qr_code_base64 = Base64.strict_encode64(png.to_s)
    end

    mail(
      to: @recipient.email,
      subject: "Zahlungsquittung: #{@course.title}"
    )
  end

  def status_changed(course_registration)
    @course_registration = course_registration
    @course = course_registration.course
    @participant = course_registration.participant
    @recipient = @participant.user
    return if @recipient.nil?

    @new_status = course_registration.status

    subject = case @new_status
    when "bestätigt"   then "Anmeldung bestätigt: #{@course.title}"
    when "storniert"   then "Anmeldung storniert: #{@course.title}"
    when "warteliste"  then "Auf der Warteliste: #{@course.title}"
    else "Status aktualisiert: #{@course.title}"
    end

    mail(to: @recipient.email, subject: subject)
  end
end
