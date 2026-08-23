class ParticipantMailer < ApplicationMailer
  def complete_profile(participant, course, reset_password_token: nil)
    @participant = participant
    @course = course
    @complete_url = if reset_password_token
      edit_user_password_url(reset_password_token: reset_password_token)
    else
      edit_participant_url(participant)
    end

    return unless MailSetting.mail_enabled?(:participant_complete_profile)

    mail(
      to: participant.user.email,
      subject: "Bitte Angaben für #{participant.first_name} #{participant.last_name} ergänzen"
    )
  end

  # changed_field_labels: Array menschenlesbarer Feldnamen (z.B. ["Strasse", "PLZ"]),
  # die sich beim letzten Speichern geändert haben.
  def profile_updated_admin_notice(participant, changed_field_labels, admin_user)
    @participant = participant
    @changed_field_labels = changed_field_labels
    @admin_user = admin_user
    @participant_url = participant_url(participant)

    return unless MailSetting.mail_enabled?(:participant_profile_updated_admin)

    mail(
      to: admin_user.email,
      subject: "Profil geändert: #{participant.first_name} #{participant.last_name}"
    )
  end
end
