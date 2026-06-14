class AttendanceReminderMailer < ApplicationMailer
  def trainer_reminder(training_session, trainer)
    @training_session = training_session
    @trainer = trainer
    @course = training_session.course
    @training_session_url = training_session_url(training_session)

    mail(
      to: trainer.user.email,
      subject: "Erinnerung: Anwesenheit für #{@course.title} noch nicht erfasst"
    )
  end

  def admin_notification(training_session)
    @training_session = training_session
    @course = training_session.course
    @trainer_names = training_session.course.course_trainers.map { |ct| ct.trainer.full_name }
    @training_session_url = training_session_url(training_session)

    mail(
      to: User.where(admin: true).pluck(:email),
      subject: "⚠️ Anwesenheit nicht erfasst: #{@course.title} (#{I18n.l(training_session.start_time.to_date)})"
    )
  end

  def admin_notification_for(training_session, admin_user)
    @training_session = training_session
    @course = training_session.course
    @trainer_names = training_session.course.course_trainers.map { |ct| ct.trainer.full_name }
    @training_session_url = training_session_url(training_session)

    mail(
      to: admin_user.email,
      subject: "⚠️ Anwesenheit nicht erfasst: #{@course.title} (#{I18n.l(training_session.start_time.to_date)})",
      template_name: "admin_notification"
    )
  end
end
