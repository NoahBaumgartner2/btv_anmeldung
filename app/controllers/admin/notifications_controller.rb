# Benachrichtigungszentrale: zentrale Übersicht über ALLE automatischen
# E-Mail-Benachrichtigungen des Systems (NotificationCatalog) – ein-/ausschaltbar
# mit Erklärung, wer die Mail erhält, und einer Live-Vorschau mit Beispieldaten.
module Admin
  class NotificationsController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!
    before_action :set_entry, only: [ :preview, :toggle ]

    def index
      @mail_setting = MailSetting.current
      @grouped = NotificationCatalog.by_category
    end

    # Rendert die echte Mail-Vorlage mit Beispieldaten – ohne Layout, für ein
    # <iframe> in der Übersicht.
    def preview
      unless @entry.preview_method
        render plain: "Für diesen Benachrichtigungstyp gibt es keine Vorschau.", status: :not_found
        return
      end

      mail = NotificationPreviewBuilder.public_send(@entry.preview_method)
      part = mail.html_part || mail
      render html: part.body.decoded.html_safe, layout: false
    rescue => e
      Rails.logger.error "[Admin::NotificationsController] Vorschau-Fehler für #{@entry.key}: #{e.class}: #{e.message}"
      render plain: "Vorschau konnte nicht geladen werden: #{e.message}", status: :unprocessable_entity
    end

    def toggle
      unless @entry.toggleable
        return redirect_to admin_notifications_path, alert: "Diese Benachrichtigung kann nicht deaktiviert werden."
      end

      enabled = params[:enabled] == "1"
      MailSetting.current.set_notification_enabled!(@entry.key, enabled)

      respond_to do |format|
        format.json { render json: { ok: true, enabled: enabled } }
        format.html { redirect_to admin_notifications_path }
      end
    end

    private

    def set_entry
      @entry = NotificationCatalog.find(params[:id])
      render plain: "Unbekannter Benachrichtigungstyp.", status: :not_found unless @entry
    end
  end
end
