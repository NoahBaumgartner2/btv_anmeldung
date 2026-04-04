Rails.application.config.after_initialize do
  MailSetting.apply!
rescue => e
  Rails.logger.warn "[MailSetting] Initializer skipped: #{e.message}"
end
