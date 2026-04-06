class ApplicationMailer < ActionMailer::Base
  before_action :set_club
  layout "mailer"

  default from: -> {
    name = @_club&.club_name.presence || "BTV Anmeldung"
    "#{name} <noreply@example.com>"
  }

  private

  def set_club
    @_club = ClubSetting.current
  end
end
