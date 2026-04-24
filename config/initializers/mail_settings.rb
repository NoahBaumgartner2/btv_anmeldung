Rails.application.config.after_initialize do
  MailSetting.apply! if defined?(MailSetting) && ActiveRecord::Base.connection.table_exists?("mail_settings")
rescue => e
  Rails.logger.warn "[MailSetting] Could not apply on boot: #{e.message}"
end
