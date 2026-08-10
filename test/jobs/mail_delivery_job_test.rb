require "test_helper"

class MailDeliveryJobTest < ActiveJob::TestCase
  test "retries on transient SMTP/network errors" do
    handled = MailDeliveryJob.rescue_handlers.map(&:first)
    %w[Net::SMTPServerBusy Net::ReadTimeout Net::OpenTimeout Errno::ECONNREFUSED Errno::ETIMEDOUT IOError].each do |klass|
      assert_includes handled, klass, "#{klass} sollte automatisch wiederholt werden"
    end
  end

  test "does not retry on permanent SMTP errors (would never succeed)" do
    handled = MailDeliveryJob.rescue_handlers.map(&:first)
    %w[Net::SMTPFatalError Net::SMTPAuthenticationError].each do |klass|
      assert_not_includes handled, klass, "#{klass} ist permanent - Wiederholen bringt nichts"
    end
  end
end
