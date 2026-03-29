class Attendance < ApplicationRecord
  belongs_to :training_session
  belongs_to :course_registration
end
