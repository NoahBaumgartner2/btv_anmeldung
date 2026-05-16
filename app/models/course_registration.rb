class CourseRegistration < ApplicationRecord
  belongs_to :course
  belongs_to :participant
  belongs_to :training_session, optional: true
  belongs_to :cancelled_by_trainer, class_name: "Trainer", optional: true

  has_many :attendances, dependent: :destroy

  validate :participant_has_required_fields, on: :create
  validate :no_duplicate_single_session_registration, on: :create
  validate :no_duplicate_semester_registration, on: :create
  validate :training_session_bookable, on: :create

  before_save :set_payment_expiry, if: -> { will_save_change_to_status?(to: "ausstehend") && payment_expires_at.nil? }

  def status_label
    I18n.t("course_registrations.statuses.#{status}", default: status.to_s.humanize)
  end

  def abo_entries_remaining
    return nil unless abo_entries_total.present?
    abo_entries_total - abo_entries_used.to_i
  end

  def abo_exhausted?
    return false unless abo_entries_total.present?
    abo_entries_used.to_i >= abo_entries_total
  end

  private

  def set_payment_expiry
    self.payment_expires_at = 48.hours.from_now
  end

  def no_duplicate_single_session_registration
    return unless course&.registration_mode == "single_session" && training_session_id.present? && participant_id.present?

    already_registered = CourseRegistration.where(
      participant_id: participant_id,
      course_id: course_id,
      training_session_id: training_session_id
    ).where.not(status: "storniert").exists?

    errors.add(:base, I18n.t("course_registrations.errors.duplicate_session")) if already_registered
  end

  def no_duplicate_semester_registration
    return if course.blank? || participant_id.blank?
    return if course.registration_mode == "single_session"

    already_registered = CourseRegistration.where(
      participant_id: participant_id,
      course_id: course_id
    ).where.not(status: "storniert").exists?

    if already_registered
      errors.add(:base, I18n.t("course_registrations.errors.duplicate_registration"))
    end
  end

  def training_session_bookable
    return unless training_session.present?

    if training_session.is_canceled?
      errors.add(:base, I18n.t("course_registrations.errors.session_cancelled"))
    elsif training_session.start_time <= Time.current
      errors.add(:base, I18n.t("course_registrations.errors.session_in_past"))
    end
  end

  def participant_has_required_fields
    return unless course && participant

    missing = participant.missing_fields_for(course)
    missing.each do |field|
      errors.add(:base, I18n.t("course_registrations.errors.missing_field",
                               field: Participant.field_label(field),
                               name: "#{participant.first_name} #{participant.last_name}"))
    end
  end
end
