class AttendanceReminderJob < ApplicationJob
  queue_as :default

  def perform
    sessions = TrainingSession
      .where(is_canceled: false)
      .where.not(end_time: nil)
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
        session.course.trainers.includes(:user).each do |trainer|
          next unless trainer.user&.email.present?
          next unless trainer.user.admin_notification_enabled?("attendance_reminder")
          AttendanceReminderMailer.admin_notification_for(session, trainer.user).deliver_later
        end
        session.update_columns(admin_notified_at: Time.current)
      end
    rescue => e
      Rails.logger.error "[AttendanceReminderJob] Fehler bei Session #{session.id}: #{e.class}: #{e.message}"
    end
  end
end
