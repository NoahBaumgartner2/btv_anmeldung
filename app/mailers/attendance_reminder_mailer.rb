class AttendanceReminderMailer < ApplicationMailer
  def trainer_reminder(training_session, trainer)
    @training_session = training_session
    @trainer = trainer
    @course = training_session.course
    @training_session_url = training_session_url(training_session)

    mail(
      to: trainer.user.email,
      subject: "Erinnerung: Anwesenheit für #{@course.name} noch nicht erfasst"
    )
  end

  def admin_notification(training_session)
    @training_session = training_session
    @course = training_session.course
    @trainer_emails = training_session.course.course_trainers.map { |ct| ct.trainer.user.email }
    @training_session_url = training_session_url(training_session)

    mail(
      to: User.where(role: "admin").pluck(:email),
      subject: "⚠️ Anwesenheit nicht erfasst: #{@course.name} (#{I18n.l(training_session.start_time.to_date)})"
    )
  end
end
