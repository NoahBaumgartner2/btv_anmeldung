class PaymentReminderMailer < ApplicationMailer
  def reminder(course_registration)
    @course_registration = course_registration
    @course = course_registration.course
    @participant = course_registration.participant
    @recipient = @participant.user
    @reminder_count = course_registration.payment_reminder_count

    return if @recipient.nil?

    mail(
      to: @recipient.email,
      subject: "Zahlungserinnerung: #{@course.title}"
    )
  end
end
