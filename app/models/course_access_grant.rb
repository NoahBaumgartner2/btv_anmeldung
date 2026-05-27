class CourseAccessGrant < ApplicationRecord
  belongs_to :course
  belongs_to :user

  validates :user_id, uniqueness: { scope: :course_id }

  def confirmed?
    course.course_registrations.exists?(participant: user.participants, status: "bestätigt")
  end

  def display_status
    confirmed? ? "bestätigt" : "eingeladen"
  end
end
