class CourseRegistration < ApplicationRecord
  belongs_to :course
  belongs_to :participant

  has_many :attendances, dependent: :destroy

  validate :participant_has_required_fields, on: :create

  private

  def participant_has_required_fields
    return unless course && participant

    missing = participant.missing_fields_for(course)
    missing.each do |field|
      errors.add(:base, "#{Participant.field_label(field)} fehlt für #{participant.first_name} #{participant.last_name}. Bitte zuerst im Profil ergänzen.")
    end
  end
end
