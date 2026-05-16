require "net/smtp"

class MailSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!

  def show
    @mail_setting = MailSetting.current
  rescue => e
    Rails.logger.error "[MailSettingsController] show Fehler: #{e.class}: #{e.message}"
    redirect_to dashboards_admin_path, alert: "Die E-Mail-Einstellungen konnten nicht geladen werden. Bitte versuche es später erneut."
  end

  def edit
    @mail_setting = MailSetting.current
  rescue => e
    Rails.logger.error "[MailSettingsController] edit Fehler: #{e.class}: #{e.message}"
    redirect_to dashboards_admin_path, alert: "Die E-Mail-Einstellungen konnten nicht geladen werden. Bitte versuche es später erneut."
  end

  def update
    @mail_setting = MailSetting.current

    if @mail_setting.update(mail_setting_params)
      MailSetting.apply!
      redirect_to mail_setting_path, notice: "E-Mail-Einstellungen wurden gespeichert."
    else
      render :edit, status: :unprocessable_entity
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
      :smtp_enable_starttls, :app_host
    )
  end
end
