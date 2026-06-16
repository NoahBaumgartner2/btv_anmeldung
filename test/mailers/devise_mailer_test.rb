require "test_helper"

class DeviseMailerTest < ActionMailer::TestCase
  test "confirmation_instructions nutzt first_name in Anrede" do
    user = users(:one)
    user.update!(first_name: "Lena")

    mail = Devise::Mailer.confirmation_instructions(user, "test-token")

    assert_match "Hallo Lena", mail.body.encoded
  end

  test "confirmation_instructions zeigt Vereins-Kontakt-E-Mail wenn vorhanden" do
    user = users(:one)
    club = ClubSetting.current
    original_email = club.contact_email
    original_name  = club.club_name
    club.update_columns(contact_email: "info@verein.ch", club_name: "Testverein")

    mail = Devise::Mailer.confirmation_instructions(user, "test-token")

    assert_match "info@verein.ch", mail.body.encoded
  ensure
    club.update_columns(contact_email: original_email, club_name: original_name)
  end

  test "confirmation_instructions fällt auf club_name zurück wenn keine Kontakt-E-Mail" do
    user = users(:one)
    club = ClubSetting.current
    original_email = club.contact_email
    original_name  = club.club_name
    club.update_columns(contact_email: nil, club_name: "Mein Verein")

    mail = Devise::Mailer.confirmation_instructions(user, "test-token")

    assert_match "Mein Verein", mail.body.encoded
  ensure
    club.update_columns(contact_email: original_email, club_name: original_name)
  end
end
