class CourseAccessMailer < ApplicationMailer
  def invited(user, course)
    @user = user
    @course = course
    @course_url = course_url(course)

    mail(to: user.email, subject: "Du wurdest zu einem Kurs eingeladen: #{course.title}")
  end
end
