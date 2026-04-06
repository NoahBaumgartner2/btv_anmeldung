class CourseRegistrationMailer < ApplicationMailer
  def confirmation(course_registration)
    @course_registration = course_registration
    @course = course_registration.course
    @participant = course_registration.participant
    @recipient = @participant.user

    subject = case course_registration.status
              when "bestätigt"  then "Anmeldung bestätigt: #{@course.title}"
              when "warteliste" then "Auf der Warteliste: #{@course.title}"
              else "Anmeldung erhalten: #{@course.title}"
              end

    mail(to: @recipient.email, subject: subject)
  end

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
