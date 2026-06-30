class TrainingSessionMailer < ApplicationMailer
  def cancellation_notice(training_session, participant_user)
    @training_session = training_session
    @course = training_session.course
    @participant_user = participant_user
    @training_session_url = training_session_url(training_session)

    mail(
      to: participant_user.email,
      subject: "Training abgesagt: #{@course.title} am #{I18n.l(training_session.start_time.to_date)}"
    )
  end

  def session_unsubscription_notice(training_session, course_registration, admin_user)
    @training_session = training_session
    @course = training_session.course
    @participant = course_registration.participant
    @training_session_url = training_session_url(training_session)

    mail(
      to: admin_user.email,
      subject: "Abmeldung: #{@participant.first_name} #{@participant.last_name} – #{@course.title} am #{I18n.l(training_session.start_time.to_date)}"
    )
  end

  def unsubscribe_reminder(training_session, course_registration)
    @training_session = training_session
    @course           = training_session.course
    @participant      = course_registration.participant
    @participant_user = @participant.user
    @trainer_emails   = @course.trainers.map { |t| t.user&.email }.compact.uniq
    @my_profile_url   = my_profile_url

    mail(
      to: @participant_user.email,
      subject: "Erinnerung: Bitte abmelden – #{@participant.first_name} #{@participant.last_name} (#{@course.title})"
    )
  end

  def training_cancelled_admin_notice(training_session, admin_user)
    @training_session = training_session
    @course = training_session.course
    @admin_user = admin_user
    @training_session_url = training_session_url(training_session)

    mail(
      to: admin_user.email,
      subject: "Training abgesagt: #{@course.title} am #{I18n.l(training_session.start_time.to_date)}"
    )
  end
end
