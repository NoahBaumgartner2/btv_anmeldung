class CourseAccessMailer < ApplicationMailer
  def invited(user, course)
    @user = user
    @course = course
    @course_url = course_url(course)

    setting = MailSetting.first
    return if setting && !setting.mail_course_access_invited_enabled

    mail(to: user.email, subject: "Du wurdest zu einem Kurs eingeladen: #{course.title}")
  end
end
