class ApplicationMailer < ActionMailer::Base
  before_action :set_club
  after_deliver :log_delivery
  layout "mailer"
  helper :mailer
  helper :mail_formatting

  default from: -> { MailSetting.current.from_header.presence || "BTV Anmeldung <noreply@btvbern-anmeldung.ch>" }

  private

  def set_club
    @_club = ClubSetting.current
  end

  # Liest die Angaben aus den Instanzvariablen der einzelnen Mailer. Ein Fehler hier darf
  # nicht hochgehen: Die Mail ist schon raus, ein Job-Retry würde sie doppelt senden.
  def log_delivery
    return if message.to.blank? || !message.perform_deliveries

    MailLog.record(
      kind: "#{mailer_name.delete_suffix('_mailer')}.#{action_name}",
      message: message,
      course: @course || @course_registration&.course || @training_session&.course || @charge&.course,
      session: @training_session || @course_registration&.training_session,
      participant: @participant || @course_registration&.participant || @charge&.participant,
      parent: @recipient || @participant_user
    )
  rescue StandardError => e
    Rails.logger.error("[MailLog] #{self.class}##{action_name}: #{e.class}: #{e.message}")
  end
end
