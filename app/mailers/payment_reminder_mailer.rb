class PaymentReminderMailer < ApplicationMailer
  def reminder(course_registration)
    @course_registration = course_registration
    @course = course_registration.course
    @participant = course_registration.participant
    @recipient = @participant.user
    @reminder_count = course_registration.payment_reminder_count

    return if @recipient.nil?

    return unless MailSetting.mail_enabled?(:payment_reminder)

    mail(
      to: @recipient.email,
      subject: "Zahlungserinnerung: #{@course.title}"
    )
  end
end
