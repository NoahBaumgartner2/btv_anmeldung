class CourseRegistration < ApplicationRecord
  belongs_to :course
  belongs_to :participant

  has_many :attendances, dependent: :destroy
end
