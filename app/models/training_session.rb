class TrainingSession < ApplicationRecord
  belongs_to :course
  belongs_to :attendance_confirmed_by, class_name: "User", optional: true

  has_many :attendances, dependent: :destroy

  def attendance_recorded?
    is_canceled? || attendance_confirmed_at.present?
  end

  def attendance_confirmed?
    attendance_confirmed_at.present?
  end

  def confirm_attendance!(user)
    update!(attendance_confirmed_at: Time.current, attendance_confirmed_by: user)
  end

  def reopen_attendance!
    update!(attendance_confirmed_at: nil, attendance_confirmed_by: nil)
  end

  def needs_trainer_reminder?
    end_time.present? && end_time < 24.hours.ago && trainer_reminded_at.nil? && !attendance_recorded?
  end

  def needs_admin_notification?
    end_time.present? && end_time < 7.days.ago && admin_notified_at.nil? && !attendance_recorded?
  end
end
