class CourseTrainer < ApplicationRecord
  belongs_to :course
  belongs_to :trainer

  # Erlaubt das Unterdrücken der Zuweisungs-Mail (z.B. beim Seeden)
  thread_mattr_accessor :skip_assignment_notification

  def self.without_assignment_notifications
    previous = skip_assignment_notification
    self.skip_assignment_notification = true
    yield
  ensure
    self.skip_assignment_notification = previous
  end

  after_create_commit :notify_trainer_of_assignment

  private

  def notify_trainer_of_assignment
    return if self.class.skip_assignment_notification
    return if trainer&.user&.email.blank?

    CourseTrainerMailer.assigned_to_course(trainer, course).deliver_later
  end
end
