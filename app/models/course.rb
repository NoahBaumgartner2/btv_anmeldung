class Course < ApplicationRecord
  has_many :course_registrations, dependent: :destroy
  has_many :registrations, through: :course_registrations
end