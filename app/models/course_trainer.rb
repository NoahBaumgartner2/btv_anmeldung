class CourseTrainer < ApplicationRecord
  belongs_to :course
  belongs_to :trainer
end
