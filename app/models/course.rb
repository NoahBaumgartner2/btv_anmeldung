class Course < ApplicationRecord
  has_many :course_registrations, dependent: :destroy
  has_many :participants, through: :course_registrations

  # Das hier kommt neu dazu:
  has_many :course_trainers, dependent: :destroy
  has_many :trainers, through: :course_trainers

  has_many :training_sessions, dependent: :destroy
end