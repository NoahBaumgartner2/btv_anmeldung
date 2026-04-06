class Participant < ApplicationRecord
  belongs_to :user

  has_many :course_registrations, dependent: :destroy
  has_many :courses, through: :course_registrations

  GENDERS = %w[männlich weiblich].freeze

  validates :first_name, :last_name, :date_of_birth, :gender, :phone_number, presence: true
  validates :gender, inclusion: { in: GENDERS }
  validates :first_name, uniqueness: {
    scope: [:last_name, :date_of_birth, :user_id],
    message: "– diese Person ist in deinem Profil bereits erfasst"
  }

  # Gibt fehlende Pflichtfelder für einen bestimmten Kurs zurück (als Symbole)
  def missing_fields_for(course)
    course.required_participant_fields.select { |field| self[field].blank? }
  end

  # Human-readable Label für ein Pflichtfeld
  def self.field_label(field)
    Course::CONFIGURABLE_REQUIRED_FIELDS[field] || field.to_s.humanize
  end
end
