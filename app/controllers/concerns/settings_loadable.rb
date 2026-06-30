# Lädt die Datensätze für die vier Einstellungs-Tabs (Admin::SettingsController).
# Wird auch von den einzelnen Singleton-Controllern eingebunden, damit ein
# fehlgeschlagenes `update` den jeweiligen Tab mit Inline-Fehlern neu rendern kann.
# Singleton-Objekte werden mit `||=` geladen, damit ein bereits gesetztes
# (ungültiges) Objekt aus dem update nicht überschrieben wird.
module SettingsLoadable
  extend ActiveSupport::Concern

  private

  def load_communication_settings
    @mail_setting       ||= MailSetting.current
    @infomaniak_setting ||= InfomaniakSetting.current
    @newsletter_drafts_count = Newsletter.drafts.count
    @newsletter_sent_count   = Newsletter.sent.count
    @subscriber_count        = NewsletterSubscriber.subscribed.count
  end

  def load_club_settings
    @club_setting ||= ClubSetting.current
  end

  def load_payment_settings
    @payment_setting ||= PaymentSetting.current
  end

  def load_data_settings
    @export_profiles ||= ExportProfile.order(:name)
  end
end
