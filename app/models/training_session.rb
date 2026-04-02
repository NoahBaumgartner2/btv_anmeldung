class TrainingSession < ApplicationRecord
  belongs_to :course

  has_many :attendances, dependent: :destroy

  def attendance_recorded?
    is_canceled? || attendances.exists?
  end

  def needs_trainer_reminder?
    end_time < 8.hours.ago && trainer_reminded_at.nil? && !attendance_recorded?
  end

  def needs_admin_notification?
    end_time < 7.days.ago && admin_notified_at.nil? && !attendance_recorded?
  end
end
