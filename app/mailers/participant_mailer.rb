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
end
