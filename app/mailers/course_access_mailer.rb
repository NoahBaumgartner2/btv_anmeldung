class CourseAccessMailer < ApplicationMailer
  def invited(user, course)
    @user = user
    @course = course
    @course_url = course_url(course)

    return unless MailSetting.mail_enabled?(:course_access_invited)

    mail(to: user.email, subject: "Du wurdest zu einem Kurs eingeladen: #{course.title}")
  end
end
