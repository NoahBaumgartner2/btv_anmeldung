class Trainer < ApplicationRecord
  belongs_to :user
  
  has_many :course_trainers, dependent: :destroy
  has_many :courses, through: :course_trainers
end