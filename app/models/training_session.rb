class TrainingSession < ApplicationRecord
  belongs_to :course
  belongs_to :attendance_confirmed_by, class_name: "User", optional: true

  has_many :attendances, dependent: :destroy

  def past?
    reference = end_time || start_time
    reference.present? && reference < Time.current
  end

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

  # Belegte Plätze für DIESE Session: Semester-Anmeldungen (training_session_id
  # nil) zählen für jede Session des Kurses mit, da diese Teilnehmer:innen jedes
  # Mal anwesend sind – sonst würden Abo-Buchungen sie überbuchen.
  def occupied_spots
    CourseRegistration
      .where(course_id: course_id, status: %w[bestätigt schnuppern])
      .where("training_session_id = ? OR training_session_id IS NULL", id)
      .count
  end
end
