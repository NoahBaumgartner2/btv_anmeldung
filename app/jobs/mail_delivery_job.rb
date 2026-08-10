require "net/smtp"

# Rails' default ActionMailer::MailDeliveryJob has NO retry logic at all - a
# single transient SMTP hiccup (timeout, connection refused, temporary "too
# busy"/rate-limit) permanently loses the mail with zero visibility (it just
# sits in Solid Queue's failed_executions table forever). Production had
# 8000+ such failures piled up, including registration confirmations, and
# recurring bursts of Net::SMTPServerBusy from Infomaniak's daily sending
# quota ("You have reached the maximum number of sent emails within a
# 24-hours period") - a case that WOULD have succeeded on retry once the
# quota reset a few hours later.
#
# Only genuinely transient errors are retried here. Permanent rejections
# (invalid recipient/domain, wrong SMTP credentials) are NOT retried - no
# amount of waiting fixes those, and endlessly retrying them would just
# waste queue capacity.
class MailDeliveryJob < ActionMailer::MailDeliveryJob
  retry_on Net::SMTPServerBusy, Net::ReadTimeout, Net::OpenTimeout,
           Errno::ECONNREFUSED, Errno::ETIMEDOUT, IOError,
           wait: :polynomially_longer, attempts: 13
end
