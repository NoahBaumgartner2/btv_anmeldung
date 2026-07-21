require "base64"

class CourseRegistrationMailer < ApplicationMailer
  def confirmation(course_registration)
    @course_registration = course_registration
    @course = course_registration.course
    @participant = course_registration.participant
    @recipient = @participant.user
    return if @recipient.nil?

    setting = MailSetting.first
    return if setting && !setting.mail_registration_confirmation_enabled

    # "ausstehend" (offener Checkout) und "platz_frei" (angebotener Platz) haben eigene Mails
    # (waitlist_promoted) bzw. brauchen keine Bestätigung. Da deliver_later den Datensatz beim
    # Job-Lauf neu lädt, kann confirmation sonst mit so einem Status rendern und der else-Zweig
    # der Vorlage zeigt fälschlich "Du stehst auf der Warteliste".
    return if %w[ausstehend platz_frei].include?(course_registration.status)

    @trainer_contacts = @course.trainers.includes(:user)
                               .map { |t| { name: t.full_name, email: t.user&.email, phone: t.phone } }
                               .select { |c| c[:email].present? || c[:phone].present? }

    if [ "bestätigt", "schnuppern" ].include?(course_registration.status) && @course.has_ticketing?
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

    # Abos haben kein einzelnes Training, von dem man sich "abmelden" könnte – die
    # generische Vorlage passt inhaltlich nicht. Sobald das Abo aktiv ist (bestätigt),
    # erklärt eine eigene Vorlage stattdessen die Einlösung über die Buchungsseite.
    if @course.abo? && course_registration.status == "bestätigt"
      @abo_sessions_url = abo_sessions_course_registration_url(course_registration)
      return mail(to: @recipient.email, subject: "Abo aktiviert: #{@course.title}", template_name: "abo_confirmation")
    end

    mail(to: @recipient.email, subject: subject)
  end

  def waitlist_promoted(course_registration)
    @course_registration = course_registration
    @course = course_registration.course
    @participant = course_registration.participant
    @recipient = @participant.user
    return if @recipient.nil?

    setting = MailSetting.first
    return if setting && !setting.mail_waitlist_promoted_enabled

    @registration_url = course_registration_url(course_registration)
    # "platz_frei": der Wartende darf zwischen Schnuppern und regulärer Anmeldung wählen.
    @decision_pending = course_registration.status == "platz_frei"
    @needs_payment = !@decision_pending && @course.has_payment? && @course.price_cents.to_i > 0 && !course_registration.abo_booking?
    @checkout_preview_url = checkout_preview_registration_url(course_registration) if @needs_payment

    subject = if @decision_pending
      "Du hast einen Platz – jetzt entscheiden: #{@course.title}"
    else
      "Du hast einen Platz erhalten: #{@course.title}"
    end

    mail(to: @recipient.email, subject: subject)
  end

  def cancelled_by_trainer(course_registration)
    @course_registration = course_registration
    @course       = course_registration.course
    @participant  = course_registration.participant
    @recipient    = @participant.user
    return if @recipient.nil?

    setting = MailSetting.first
    return if setting && !setting.mail_cancelled_by_trainer_enabled

    @reason       = course_registration.cancellation_reason
    @cancelled_by = course_registration.cancelled_by_trainer&.user&.email

    mail(
      to: @recipient.email,
      subject: "Abmeldung vom Kurs: #{@course.title}"
    )
  end

  def refund_failed_notice(course_registration, admin_user, error_message, refund_amount_cents = nil)
    @course_registration = course_registration
    @course       = course_registration.course
    @participant  = course_registration.participant
    @parent       = @participant.user
    @error_message = error_message
    @refund_amount_cents = refund_amount_cents
    @refund_amount_chf   = refund_amount_cents ? format("%.2f", refund_amount_cents / 100.0) : nil
    @recipient    = admin_user

    mail(
      to: admin_user.email,
      subject: "Rückerstattung fehlgeschlagen: #{@participant.first_name} #{@participant.last_name} (#{@course.title})"
    )
  end

  # Informiert den Admin automatisch, nachdem ein Trainer ein Kind ausgeschlossen hat.
  def admin_refund_done_notice(course_registration, admin_user, refund_amount_cents)
    @course_registration = course_registration
    @course       = course_registration.course
    @participant  = course_registration.participant
    @parent       = @participant.user
    @cancelled_by = course_registration.cancelled_by_trainer&.full_name
    @refund_amount_cents = refund_amount_cents
    @refund_amount_chf   = refund_amount_cents ? format("%.2f", refund_amount_cents / 100.0) : nil
    @recipient    = admin_user

    mail(
      to: admin_user.email,
      subject: "Teilnehmer abgemeldet: #{@participant.first_name} #{@participant.last_name} – #{@course.title}"
    )
  end

  # Wird verschickt, wenn ein Admin ein bestehendes (Alt-)Abo mit Resteintritten
  # manuell importiert, statt es neu zu verkaufen (siehe CoursesController#enroll_participant).
  def abo_imported(course_registration)
    @course_registration = course_registration
    @course = course_registration.course
    @participant = course_registration.participant
    @recipient = @participant.user
    return if @recipient.nil?

    mail(to: @recipient.email, subject: "Ihr bestehendes Abo wurde übertragen: #{@course.title}")
  end

  def abo_exhausted(course_registration)
    @course_registration = course_registration
    @course = course_registration.course
    @participant = course_registration.participant
    @recipient = @participant.user
    return if @recipient.nil?

    mail(
      to: @recipient.email,
      subject: "Abo aufgebraucht: #{@course.title}"
    )
  end

  def payment_expired(course_registration, was_spot_offer: false)
    @course_registration = course_registration
    @course = course_registration.course
    @participant = course_registration.participant
    @recipient = @participant.user
    @was_spot_offer = was_spot_offer
    return if @recipient.nil?

    # Schutz-Guard: Schnupperplätze laufen nie über die 48h-Zahlungsfrist ab –
    # für sie ist trial_expired (Schnuppertraining + 7 Tage) zuständig.
    return if course_registration.trial?

    setting = MailSetting.first
    return if setting && !setting.mail_payment_expired_enabled

    mail(
      to: @recipient.email,
      subject: "Reservierung abgelaufen: #{@course.title}"
    )
  end

  # Wird verschickt, wenn ein Schnupperplatz nach Ablauf der Frist
  # (Schnuppertraining + 7 Tage) automatisch storniert wurde.
  def trial_expired(course_registration)
    @course_registration = course_registration
    @course = course_registration.course
    @participant = course_registration.participant
    @recipient = @participant.user
    return if @recipient.nil?

    setting = MailSetting.first
    return if setting && !setting.mail_payment_expired_enabled

    @trial_session = course_registration.trial_session || course_registration.training_session

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
      subject: "Zahlungsbeleg: #{@course.title}"
    )
  end

  def self_cancelled(course_registration, refund_amount_cents: nil)
    @course_registration = course_registration
    @course = course_registration.course
    @participant = course_registration.participant
    @recipient = @participant.user
    return if @recipient.nil?

    @refund_amount_cents = refund_amount_cents
    @refund_amount_chf   = refund_amount_cents ? format("%.2f", refund_amount_cents / 100.0) : nil
    @cancelled_at        = course_registration.cancelled_at || Time.current
    @trainer_contacts    = @course.trainers.includes(:user)
                                  .map { |t| { name: t.full_name, email: t.user&.email } }
                                  .select { |c| c[:email].present? }

    mail(
      to: @recipient.email,
      subject: "Abmeldung bestätigt: #{@course.title}"
    )
  end

  def admin_cancel_notice(course_registration, admin_user)
    @course_registration = course_registration
    @course       = course_registration.course
    @participant  = course_registration.participant
    @parent       = @participant.user
    @recipient    = admin_user
    @cancelled_by_trainer = course_registration.cancelled_by_trainer&.user&.email

    mail(
      to: admin_user.email,
      subject: "Abmeldung: #{@participant.first_name} #{@participant.last_name} – #{@course.title}"
    )
  end

  def trainer_cancel_notice(course_registration, trainer_user)
    @course_registration = course_registration
    @course       = course_registration.course
    @participant  = course_registration.participant
    @parent       = @participant.user
    @recipient    = trainer_user

    mail(
      to: trainer_user.email,
      subject: "Abmeldung: #{@participant.first_name} #{@participant.last_name} – #{@course.title}"
    )
  end

  def custom_message(course_registration, subject:, body:, sender:)
    @course_registration = course_registration
    @course = course_registration.course
    @participant = course_registration.participant
    @recipient = @participant.user
    @custom_subject = subject
    @custom_body = body
    @sender_name  = sender.full_name
    @sender_email = sender.is_a?(Trainer) ? sender.user&.email : sender.try(:email)
    return if @recipient.nil?

    mail(to: @recipient.email, subject: "Nachricht von #{@sender_name}")
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
