class RolloverCoursePeriodsJob < ApplicationJob
  queue_as :default

  def perform
    scope = Course.where.not(term_id: nil).includes(:term, :next_course, :training_sessions)

    rolled_over = 0
    errors = 0

    scope.find_each do |course|
      next unless course.rollover_due?

      unless course.auto_rollover?
        notify_admins_once(course)
        next
      end

      begin
        new_course = CourseRolloverService.roll_over!(course)
        rolled_over += 1
        Rails.logger.info "[RolloverCoursePeriodsJob] Kurs #{course.id} (#{course.title}) automatisch verlängert -> Kurs #{new_course.id} (Term #{new_course.term.name})."
      rescue ActiveRecord::RecordNotUnique
        Rails.logger.info "[RolloverCoursePeriodsJob] Kurs #{course.id} wurde bereits verlängert (gleichzeitiger Lauf)."
      rescue => e
        errors += 1
        Rails.logger.error "[RolloverCoursePeriodsJob] Fehler bei Kurs #{course.id}: #{e.class}: #{e.message}"
      end
    end

    Rails.logger.info "[RolloverCoursePeriodsJob] Abgeschlossen: #{rolled_over} verlängert, #{errors} Fehler."
  end

  private

  # Nur einmal benachrichtigen, nicht bei jedem täglichen Lauf erneut.
  def notify_admins_once(course)
    return if course.rollover_notified_at.present?

    CourseRolloverMailer.ready_for_manual_rollover(course).deliver_later
    course.update_columns(rollover_notified_at: Time.current)
    Rails.logger.info "[RolloverCoursePeriodsJob] Kurs #{course.id} (#{course.title}) bereit – Admins benachrichtigt (manueller Modus)."
  end
end
