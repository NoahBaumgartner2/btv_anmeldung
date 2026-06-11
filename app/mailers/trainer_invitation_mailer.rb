class TrainerInvitationMailer < ApplicationMailer
  def invite(trainer, token)
    @trainer   = trainer
    @reset_url = edit_user_password_url(reset_password_token: token)
    mail(to: trainer.user.email, subject: "Du wurdest als Trainer eingeladen – Bitte Passwort setzen")
  end
end
