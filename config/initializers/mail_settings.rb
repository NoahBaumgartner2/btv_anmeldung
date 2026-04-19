Rails.application.config.after_initialize do
  MailSetting.apply!

  from = ActionMailer::Base.default_options[:from]
  Devise.mailer_sender = from if from.present?
rescue => e
  Rails.logger.warn "[MailSetting] Initializer skipped: #{e.message}"
end
