class AddEnrolledAtToCourseRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :course_registrations, :enrolled_at, :datetime
  end
end
