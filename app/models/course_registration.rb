class CourseRegistration < ApplicationRecord
  belongs_to :course
  belongs_to :participant
  belongs_to :training_session, optional: true
  belongs_to :cancelled_by_trainer, class_name: "Trainer", optional: true

  has_many :attendances, dependent: :destroy

  validate :participant_has_required_fields, on: :create
  validate :no_duplicate_single_session_registration, on: :create
  validate :training_session_bookable, on: :create

  private

  def no_duplicate_single_session_registration
    return unless course&.registration_mode == "single_session" && training_session_id.present? && participant_id.present?

    already_registered = CourseRegistration.where(
      participant_id: participant_id,
      course_id: course_id,
      training_session_id: training_session_id
    ).where.not(status: "storniert").exists?

    errors.add(:base, "Dieses Kind ist für diesen Termin bereits angemeldet.") if already_registered
  end

  def training_session_bookable
    return unless training_session.present?

    if training_session.is_canceled?
      errors.add(:base, "Dieser Termin wurde leider abgesagt.")
    elsif training_session.start_time <= Time.current
      errors.add(:base, "Dieser Termin liegt in der Vergangenheit und kann nicht mehr gebucht werden.")
    end
  end

  def participant_has_required_fields
    return unless course && participant

    missing = participant.missing_fields_for(course)
    missing.each do |field|
      errors.add(:base, "#{Participant.field_label(field)} fehlt für #{participant.first_name} #{participant.last_name}. Bitte zuerst im Profil ergänzen.")
    end
  end
end
