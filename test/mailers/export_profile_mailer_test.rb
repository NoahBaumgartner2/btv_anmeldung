require "test_helper"

class ExportProfileMailerTest < ActionMailer::TestCase
  test "scheduled_export sendet E-Mail mit CSV-Anhang" do
    profile = export_profiles(:one)
    participants = Participant.none
    mail = ExportProfileMailer.scheduled_export(profile, participants)

    assert_equal [ profile.recipient_email ], mail.to
    assert_match profile.name, mail.subject
    assert mail.attachments.any?
  end
end
