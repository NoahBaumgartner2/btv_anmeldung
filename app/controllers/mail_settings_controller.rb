require "net/smtp"

class MailSettingsController < ApplicationController
  include SettingsLoadable

  before_action :authenticate_user!
  before_action :authorize_admin!

  # E-Mail-Einstellungen leben jetzt im Kommunikation-Tab des Einstellungs-Hubs.
  def show
    redirect_to admin_settings_communication_path
  end

  def edit
    redirect_to admin_settings_communication_path
  end

  def update
    @mail_setting = MailSetting.current

    if @mail_setting.update(mail_setting_params)
      MailSetting.apply!
      respond_to do |format|
        format.json { render json: { ok: true } }
        format.html { redirect_to admin_settings_communication_path, notice: "E-Mail-Einstellungen wurden gespeichert." }
      end
    else
      respond_to do |format|
        format.json { render json: { ok: false, errors: @mail_setting.errors.full_messages }, status: :unprocessable_entity }
        format.html do
          load_communication_settings
          render "admin/settings/communication", status: :unprocessable_entity
        end
      end
    end
  end

  def test_email
    to = params[:test_to].to_s.strip

    unless to.match?(URI::MailTo::EMAIL_REGEXP)
      return redirect_to mail_setting_path, alert: "Bitte eine gültige E-Mail-Adresse eingeben."
    end

    TestMailer.test_email(to).deliver_now
    redirect_to mail_setting_path, notice: "Test-E-Mail wurde an #{to} gesendet."
  rescue Net::SMTPAuthenticationError => e
    Rails.logger.error "[MailSettingsController] test_email SMTP Auth: #{e.class}: #{e.message}"
    redirect_to mail_setting_path, alert: t("mail_settings.flash.test_auth_error")
  rescue => e
    Rails.logger.error "[MailSettingsController] test_email Fehler: #{e.class}: #{e.message}"
    detail = "#{e.class} – #{e.message}".truncate(200)
    redirect_to mail_setting_path, alert: t("mail_settings.flash.test_error", detail: detail)
  end

  private

  def mail_setting_params
    params.require(:mail_setting).permit(
      :smtp_host, :smtp_port, :smtp_username, :smtp_password,
      :smtp_from_address, :smtp_from_name, :smtp_authentication,
      :smtp_enable_starttls, :app_host,
      :mail_registration_confirmation_enabled,
      :mail_waitlist_promoted_enabled,
      :mail_cancelled_by_trainer_enabled,
      :mail_payment_expired_enabled,
      :mail_course_access_invited_enabled
    )
  end
end
