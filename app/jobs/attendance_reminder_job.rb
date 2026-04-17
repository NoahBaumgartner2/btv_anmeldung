class AttendanceReminderJob < ApplicationJob
  queue_as :default

  def perform
    sessions = TrainingSession
      .where(is_canceled: false)
      .where("end_time < ?", Time.current)
      .includes(course: { course_trainers: { trainer: :user } })

    sessions.each do |session|
      next if session.attendance_recorded?

      if session.needs_trainer_reminder?
        session.course.course_trainers.each do |ct|
          AttendanceReminderMailer.trainer_reminder(session, ct.trainer).deliver_later
        end
        session.update_columns(trainer_reminded_at: Time.current)
      end

      if session.needs_admin_notification?
        AttendanceReminderMailer.admin_notification(session).deliver_later
        session.update_columns(admin_notified_at: Time.current)
      end
    end
  end
end
