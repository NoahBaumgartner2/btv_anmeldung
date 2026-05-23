class ApplicationMailer < ActionMailer::Base
  before_action :set_club
  layout "mailer"

  default from: -> { MailSetting.current.from_header.presence || "BTV Anmeldung <noreply@btvbern-anmeldung.ch>" }

  private

  def set_club
    @_club = ClubSetting.current
  end
end
