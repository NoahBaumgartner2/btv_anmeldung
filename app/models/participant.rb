class Participant < ApplicationRecord
  belongs_to :user
  
  has_many :course_registrations, dependent: :destroy
  has_many :courses, through: :course_registrations
end