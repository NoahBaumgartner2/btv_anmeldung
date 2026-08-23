class CourseTrainerMailer < ApplicationMailer
  def assigned_to_course(trainer, course)
    @trainer = trainer
    @course  = course

    return unless MailSetting.mail_enabled?(:trainer_assigned)

    mail(to: trainer.user.email,
         subject: "Du wurdest dem Kurs „#{course.title}“ als Leiter zugeteilt")
  end

  # changed_field_labels: Array menschenlesbarer Feldnamen (z.B. ["Strasse", "IBAN"]),
  # die sich beim letzten Speichern geändert haben.
  def profile_updated_admin_notice(trainer, changed_field_labels, admin_user)
    @trainer = trainer
    @changed_field_labels = changed_field_labels
    @admin_user = admin_user
    @trainer_url = trainer_url(trainer)

    return unless MailSetting.mail_enabled?(:trainer_profile_updated_admin)

    mail(to: admin_user.email, subject: "Profil geändert: #{trainer.full_name}")
  end
end
