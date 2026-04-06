class CourseRegistrationMailer < ApplicationMailer
  def waitlist_promoted(course_registration)
    @course_registration = course_registration
    @course = course_registration.course
    @participant = course_registration.participant
    @recipient = @participant.user

    mail(
      to: @recipient.email,
      subject: "Du hast einen Platz erhalten: #{@course.title}"
    )
  end
end
