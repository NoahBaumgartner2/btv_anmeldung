class Participant < ApplicationRecord
  belongs_to :user

  has_many :course_registrations, dependent: :destroy
  has_many :courses, through: :course_registrations

  GENDERS = %w[männlich weiblich].freeze

  validates :first_name, :last_name, :date_of_birth, :gender, presence: true
  validates :gender, inclusion: { in: GENDERS }
  validates :first_name, uniqueness: {
    scope: [:last_name, :date_of_birth, :user_id],
    message: "– diese Person ist in deinem Profil bereits erfasst"
  }
end
