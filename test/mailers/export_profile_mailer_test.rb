require "test_helper"

class ExportProfileMailerTest < ActionMailer::TestCase
  test "scheduled_export" do
    mail = ExportProfileMailer.scheduled_export
    assert_equal "Scheduled export", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end
end
