# Benachrichtigt Admins, wenn ein Kurs mit auto_rollover: false bereit für
# die manuelle Verlängerung ist (siehe RolloverCoursePeriodsJob und
# CoursesController#roll_over).
class CourseRolloverMailer < ApplicationMailer
  def ready_for_manual_rollover(course)
    @course = course
    @manage_url = manage_course_url(course)

    return unless MailSetting.mail_enabled?(:course_rollover_ready)

    mail(
      to: User.where(admin: true).pluck(:email),
      subject: "Bereit zur Verlängerung: #{course.title} (#{course.next_term&.name})"
    )
  end
end
