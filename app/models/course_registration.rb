class CourseRegistration < ApplicationRecord
  belongs_to :course
  belongs_to :participant

  has_many :attendances, dependent: :destroy

  validate :participant_has_required_fields, on: :create

  after_destroy :promote_from_waitlist
  after_update :promote_from_waitlist, if: -> { saved_change_to_status?(to: "storniert") }

  private

  def promote_from_waitlist
    return unless course.max_participants.present?

    confirmed_count = course.course_registrations.where(status: "bestätigt").count
    return unless confirmed_count < course.max_participants

    next_in_line = course.course_registrations
                         .where(status: "warteliste")
                         .order(:created_at)
                         .first
    return unless next_in_line

    next_in_line.update_columns(status: "bestätigt")
    CourseRegistrationMailer.waitlist_promoted(next_in_line).deliver_later
  end

  def participant_has_required_fields
    return unless course && participant

    missing = participant.missing_fields_for(course)
    missing.each do |field|
      errors.add(:base, "#{Participant.field_label(field)} fehlt für #{participant.first_name} #{participant.last_name}. Bitte zuerst im Profil ergänzen.")
    end
  end
end
